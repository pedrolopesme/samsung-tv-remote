import Foundation
import Observation

/// Estado central do app: configuração da TV, ciclo de conexão e envio de teclas.
///
/// Máquina de estados descrita em `docs/specs/0001-remote-control-mvp.md` (seção "Estados").
@MainActor
@Observable
final class RemoteModel {
    enum Status: Equatable {
        case notConfigured
        case disconnected
        case connecting
        case awaitingApproval
        case connected
        case waking
    }

    /// Nome que aparece no pop-up "Permitir este dispositivo?" da TV.
    /// Mudar esse nome invalida o token já pareado.
    static let clientName = "Mac Remote"

    private(set) var status: Status
    private(set) var configuration: TVConfiguration?
    var errorMessage: String?

    private let store: ConfigurationStore
    private let tokens: any TokenStore
    private let appFavorites: AppFavoritesStore
    private var client: TVWebSocketClient?
    private var connectTask: Task<Void, Never>?

    /// Apps conhecidos resolvidos contra a última resposta de `ed.installedApp.get` desta conexão.
    private(set) var resolvedApps: [ResolvedApp] = []
    /// Chaves de `KnownApp` marcadas como favoritas, na ordem em que foram marcadas.
    private(set) var favoriteKeys: [String]
    /// `true` assim que uma resposta de `ed.installedApp.get` foi processada (mesmo que vazia).
    private(set) var appsQueried = false

    init(
        store: ConfigurationStore = ConfigurationStore(),
        tokens: any TokenStore = KeychainTokenStore(),
        appFavorites: AppFavoritesStore = AppFavoritesStore()
    ) {
        self.store = store
        self.tokens = tokens
        self.appFavorites = appFavorites
        self.favoriteKeys = appFavorites.load()
        let saved = store.load()
        self.configuration = saved
        self.status = saved == nil ? .notConfigured : .disconnected
    }

    var isBusy: Bool {
        status == .connecting || status == .awaitingApproval || status == .waking
    }

    // MARK: - Setup

    /// Primeiro uso: valida o IP pela API REST, salva modelo/MAC e inicia o pareamento.
    func setUp(host rawHost: String) async {
        let host = rawHost.trimmingCharacters(in: .whitespacesAndNewlines)
        errorMessage = nil
        status = .connecting
        do {
            let info = try await TVInfoClient.fetch(host: host)
            let configuration = TVConfiguration(
                host: host,
                macAddress: info.device.wifiMac.flatMap(WakeOnLAN.formatted),
                name: info.displayName,
                modelName: info.device.modelName
            )
            apply(configuration)
            await connect()
        } catch {
            status = configuration == nil ? .notConfigured : .disconnected
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Edição manual nas Preferências.
    func updateConfiguration(host: String, macAddress: String) {
        guard var configuration else { return }
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let mac = macAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if host != configuration.host {
            dropConnection()
            configuration.host = host
        }
        configuration.macAddress = mac.isEmpty ? nil : (WakeOnLAN.formatted(mac) ?? mac)
        apply(configuration)
    }

    /// Apaga o token e força o pop-up de permissão na próxima conexão.
    func resetPairing() {
        guard let configuration else { return }
        tokens.setToken(nil, for: configuration.host)
        dropConnection()
        Task { await connect() }
    }

    func forgetTV() {
        if let configuration { tokens.setToken(nil, for: configuration.host) }
        dropConnection()
        configuration = nil
        store.save(nil)
        status = .notConfigured
        errorMessage = nil
    }

    // MARK: - Conexão

    /// Conecta se ainda não estiver conectado. Chamadas concorrentes esperam a mesma tentativa.
    func connect() async {
        if status == .connected, client != nil { return }
        if let connectTask {
            await connectTask.value
            return
        }
        let task = Task { await performConnect() }
        connectTask = task
        await task.value
        connectTask = nil
    }

    private func performConnect() async {
        guard let configuration else {
            status = .notConfigured
            return
        }
        errorMessage = nil
        status = .connecting

        // 1) Checagem rápida via REST: evita esperar o timeout do WebSocket com a TV desligada.
        do {
            let info = try await TVInfoClient.fetch(host: configuration.host)
            refreshDeviceInfo(info)
            guard info.isOn else {
                status = .disconnected
                errorMessage = "A TV está em standby. Toque no botão de energia para ligar."
                return
            }
        } catch {
            status = .disconnected
            errorMessage = (error as? LocalizedError)?.errorDescription
            return
        }

        // 2) WebSocket. Se demorar, quase sempre é o pop-up de permissão na TV.
        let client = TVWebSocketClient(host: configuration.host)
        client.onDisconnect = { [weak self, weak client] in
            Task { @MainActor in
                guard let self, let client else { return }
                self.handleDisconnect(of: client)
            }
        }
        client.onMessage = { [weak self] text in
            guard let event = InstalledAppsEvent.parse(text) else { return }
            Task { @MainActor in
                self?.applyInstalledApps(event.apps)
            }
        }
        let approvalHint = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1200))
            guard !Task.isCancelled, let self, self.status == .connecting else { return }
            self.status = .awaitingApproval
        }
        defer { approvalHint.cancel() }

        let savedToken = tokens.token(for: configuration.host)
        do {
            let token = try await client.connect(clientName: Self.clientName, token: savedToken)
            if let token, token != savedToken {
                tokens.setToken(token, for: configuration.host)
            }
            self.client = client
            status = .connected
            requestInstalledApps()
            #if DEBUG
            probeLaunchNetflix()
            #endif
        } catch {
            client.disconnect()
            status = .disconnected
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func handleDisconnect(of client: TVWebSocketClient) {
        guard self.client === client else { return }
        self.client = nil
        resolvedApps = []
        appsQueried = false
        if status == .connected { status = .disconnected }
    }

    private func dropConnection() {
        client?.disconnect()
        client = nil
        resolvedApps = []
        appsQueried = false
        if configuration != nil { status = .disconnected }
    }

    // MARK: - Teclas

    func send(_ key: RemoteKey) {
        Task { await sendNow(key) }
    }

    func sendNow(_ key: RemoteKey) async {
        if client == nil { await connect() }
        guard let client = self.client else { return }
        do {
            try await client.send(RemoteMessage.key(key))
        } catch {
            // A TV derruba conexões ociosas: reconecta uma vez e reenvia.
            handleDisconnect(of: client)
            await connect()
            try? await self.client?.send(RemoteMessage.key(key))
        }
    }

    // MARK: - Apps

    /// Apps favoritos presentes na última consulta à TV, na ordem em que foram marcados.
    /// Vazio = linha de atalhos oculta (`RemoteView`), consistente com FR-4/FR-6 da spec 0002.
    var favoriteApps: [ResolvedApp] {
        let resolvedByKey = Dictionary(uniqueKeysWithValues: resolvedApps.map { ($0.id, $0) })
        return favoriteKeys.compactMap { resolvedByKey[$0] }
    }

    func setFavorite(_ key: String, isFavorite: Bool) {
        if isFavorite {
            guard !favoriteKeys.contains(key) else { return }
            favoriteKeys.append(key)
        } else {
            favoriteKeys.removeAll { $0 == key }
        }
        appFavorites.save(favoriteKeys)
    }

    /// Dispara o app pelo `appId` resolvido em `applyInstalledApps`. Fire-and-forget: a TV não
    /// confirma sucesso (FR-5/FR-6 da spec 0002).
    func launchApp(_ resolved: ResolvedApp) {
        Task { [weak self] in
            try? await self?.client?.send(RemoteMessage.launchApp(appId: resolved.appId))
        }
    }

    private func requestInstalledApps() {
        guard let client else { return }
        #if DEBUG
        print("[TV] enviando ed.installedApp.get")
        #endif
        Task { try? await client.send(RemoteMessage.installedAppsRequest()) }
    }

    #if DEBUG
    /// Teste direto e temporário: `ed.apps.launch` funciona com o `appId` de referência,
    /// sem confirmar instalação antes (já que `ed.installedApp.get`/`ms.application.get`
    /// não existem nesta geração de firmware — ver PR)? Abre Netflix de verdade se funcionar.
    /// Remover depois de confirmar.
    private func probeLaunchNetflix() {
        guard let client else { return }
        let appId = "3201907018807"
        Task {
            print("[TV] testando ed.apps.launch direto (Netflix, appId \(appId))")
            try? await client.send(RemoteMessage.launchApp(appId: appId))
        }
    }
    #endif

    private func applyInstalledApps(_ apps: [InstalledApp]) {
        appsQueried = true
        resolvedApps = KnownApp.all.compactMap { known in
            apps.first { KnownApp.normalize($0.name) == known.matchName }
                .map { ResolvedApp(app: known, appId: $0.appId) }
        }
    }

    // MARK: - Energia

    func togglePower() {
        Task {
            if status == .connected {
                await sendNow(.power)
                // Em modelos 2021, KEY_POWER com a TV ligada leva ao standby e a conexão cai.
            } else {
                await powerOn()
            }
        }
    }

    /// Wake-on-LAN + polling da API REST até a TV responder "on" (máx. ~20 s).
    func powerOn() async {
        guard let configuration else { return }
        guard let mac = configuration.macAddress, !mac.isEmpty else {
            errorMessage = "MAC da TV desconhecido. Preencha nas Preferências para ligar pela rede."
            return
        }
        errorMessage = nil
        status = .waking

        for attempt in 0..<20 {
            if attempt % 4 == 0 {
                do {
                    try WakeOnLAN.send(mac: mac)
                } catch {
                    status = .disconnected
                    errorMessage = "Falha ao enviar Wake-on-LAN: \(error.localizedDescription)"
                    return
                }
            }
            try? await Task.sleep(for: .seconds(1))
            if let info = try? await TVInfoClient.fetch(host: configuration.host, timeout: 1), info.isOn {
                await connect()
                return
            }
        }
        status = .disconnected
        errorMessage = "A TV não ligou. Verifique \"Ligar com dispositivo móvel\" nas configurações de rede da TV."
    }

    // MARK: - Helpers

    private func apply(_ configuration: TVConfiguration) {
        self.configuration = configuration
        store.save(configuration)
    }

    private func refreshDeviceInfo(_ info: TVDeviceInfo) {
        guard var configuration else { return }
        var changed = false
        if configuration.macAddress == nil, let mac = info.device.wifiMac.flatMap(WakeOnLAN.formatted) {
            configuration.macAddress = mac
            changed = true
        }
        if configuration.modelName == nil, let model = info.device.modelName {
            configuration.modelName = model
            changed = true
        }
        if changed { apply(configuration) }
    }
}
