import Foundation

enum TVConnectionError: LocalizedError, Equatable {
    case invalidHost
    case unreachable
    case notASamsungTV
    case unauthorized
    case pairingTimedOut
    case notConnected
    case invalidMACAddress

    var errorDescription: String? {
        switch self {
        case .invalidHost: "Endereço IP inválido."
        case .unreachable: "A TV não respondeu. Ela está ligada e na mesma rede?"
        case .notASamsungTV: "Esse endereço respondeu, mas não parece ser uma TV Samsung."
        case .unauthorized: "A TV recusou a conexão. Libere o app em Gerenciador de conexão de dispositivos."
        case .pairingTimedOut: "O pedido de permissão expirou na TV. Tente de novo e aceite na tela."
        case .notConnected: "Sem conexão com a TV."
        case .invalidMACAddress: "Endereço MAC inválido."
        }
    }
}

/// Conexão WebSocket com o canal `samsung.remote.control`.
///
/// - Aceita o certificado autoassinado da TV **somente** para o host configurado.
/// - Mantém a conexão viva com ping a cada 20 s e avisa via `onDisconnect` quando cai.
final class TVWebSocketClient: NSObject, URLSessionDelegate, @unchecked Sendable {
    let host: String
    var onDisconnect: (@Sendable () -> Void)?
    /// Mensagens recebidas depois do handshake (ex.: resposta de `ed.installedApp.get`).
    /// Ver spec 0002.
    var onMessage: (@Sendable (String) -> Void)?

    private lazy var session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    private var task: URLSessionWebSocketTask?
    private var receiveLoop: Task<Void, Never>?
    private var pingLoop: Task<Void, Never>?
    private let lock = NSLock()
    private var didClose = false

    init(host: String) {
        self.host = host
    }

    /// Abre a conexão e espera o handshake da TV.
    ///
    /// Na primeira vez a TV mostra o pop-up de permissão; esta chamada só retorna
    /// quando o usuário aceita (`ms.channel.connect`), recusa ou o pop-up expira.
    /// - Returns: o token devolvido pela TV (ou o token já usado, se ela não mandar outro).
    func connect(clientName: String, token: String?) async throws -> String? {
        guard let url = TVEndpoint.remoteControlURL(host: host, clientName: clientName, token: token) else {
            throw TVConnectionError.invalidHost
        }
        let task = session.webSocketTask(with: url)
        self.task = task
        task.resume()

        while true {
            let message: URLSessionWebSocketTask.Message
            do {
                message = try await task.receive()
            } catch {
                close()
                throw TVConnectionError.unreachable
            }
            guard case .string(let text) = message, let event = ChannelEvent.parse(text) else { continue }

            switch event.event {
            case ChannelEvent.connect:
                startLoops(for: task)
                return event.token ?? token
            case ChannelEvent.unauthorized:
                close()
                throw TVConnectionError.unauthorized
            case ChannelEvent.timeOut:
                close()
                throw TVConnectionError.pairingTimedOut
            default:
                continue
            }
        }
    }

    func send(_ text: String) async throws {
        guard let task, task.state == .running else { throw TVConnectionError.notConnected }
        try await task.send(.string(text))
    }

    func disconnect() {
        onDisconnect = nil
        close()
    }

    // MARK: - Internals

    private func startLoops(for task: URLSessionWebSocketTask) {
        receiveLoop = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    let message = try await task.receive()
                    if case .string(let text) = message {
                        self?.onMessage?(text)
                    }
                } catch {
                    self?.close()
                    return
                }
            }
        }
        pingLoop = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                if Task.isCancelled { return }
                task.sendPing { error in
                    if error != nil { self?.close() }
                }
            }
        }
    }

    private func close() {
        lock.lock()
        let alreadyClosed = didClose
        didClose = true
        lock.unlock()
        guard !alreadyClosed else { return }

        receiveLoop?.cancel()
        pingLoop?.cancel()
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        session.invalidateAndCancel()
        onDisconnect?()
    }

    // MARK: - URLSessionDelegate

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        // A TV usa certificado autoassinado na porta 8002. Confiamos nele apenas para o IP da TV.
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              challenge.protectionSpace.host == host,
              let trust = challenge.protectionSpace.serverTrust
        else {
            return (.performDefaultHandling, nil)
        }
        return (.useCredential, URLCredential(trust: trust))
    }
}
