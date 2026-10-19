import Darwin
import Foundation

/// Uma TV Samsung candidata encontrada via SSDP. Ver spec 0003.
struct DiscoveredTV: Identifiable, Equatable, Sendable {
    let host: String
    /// Porta UPnP onde a TV respondeu (só pra exibição — `pareamento` sempre usa 8001/8002).
    let port: Int

    var id: String { host }
}

/// Descoberta de TVs Samsung na rede local via SSDP (UPnP discovery, UDP multicast 1900).
///
/// Zero dependências (ADR 0001): socket BSD cru, mesmo estilo de `WakeOnLAN.swift`, mas aqui
/// também precisa **receber** respostas multicast, não só enviar.
///
/// `ST: urn:samsung.com:device:RemoteControlReceiver:1` (valor do roadmap) **não funciona** —
/// testado contra a AU8000 real, zero respostas. `upnp:rootdevice` funciona de verdade (ver
/// `docs/specs/0003-descoberta-automatica.md`, seção "Protocolo / dados").
///
/// Nunca lança: qualquer falha de socket/rede resulta em lista vazia (FR-6).
enum SSDPDiscovery {
    private static let multicastAddress = "239.255.255.250"
    private static let multicastPort: UInt16 = 1900
    private static let searchTarget = "upnp:rootdevice"

    /// Busca por ~`timeout` segundos. Roda numa task desvinculada do chamador — nunca bloqueia
    /// quem chamou, mesmo que o chamador esteja no `MainActor` (FR-1).
    static func discover(timeout: TimeInterval = 3) async -> [DiscoveredTV] {
        await Task.detached(priority: .utility) {
            blockingDiscover(timeout: timeout)
        }.value
    }

    private static func blockingDiscover(timeout: TimeInterval) -> [DiscoveredTV] {
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { return [] }
        defer { close(fd) }

        // Timeout curto por `recvfrom`; o laço externo controla o prazo total da busca.
        var readTimeout = timeval(tv_sec: 0, tv_usec: 300_000)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &readTimeout, socklen_t(MemoryLayout<timeval>.size))

        let request = [
            "M-SEARCH * HTTP/1.1",
            "HOST: \(multicastAddress):\(multicastPort)",
            "MAN: \"ssdp:discover\"",
            "MX: 2",
            "ST: \(searchTarget)",
            "",
            "",
        ].joined(separator: "\r\n")
        let payload = Array(request.utf8)

        var destination = sockaddr_in()
        destination.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        destination.sin_family = sa_family_t(AF_INET)
        destination.sin_port = multicastPort.bigEndian
        destination.sin_addr.s_addr = inet_addr(multicastAddress)

        let sent = payload.withUnsafeBytes { buffer in
            withUnsafePointer(to: &destination) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { address in
                    sendto(fd, buffer.baseAddress, buffer.count, 0, address, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent > 0 else { return [] }

        // Dedup por host: a mesma TV manda várias respostas Samsung válidas em portas
        // diferentes (serviço principal + DLNA MediaRenderer) — sem isso ela apareceria
        // duplicada na lista.
        var byHost: [String: DiscoveredTV] = [:]
        var buffer = [UInt8](repeating: 0, count: 2048)
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            let received = buffer.withUnsafeMutableBytes { pointer in
                recvfrom(fd, pointer.baseAddress, pointer.count, 0, nil, nil)
            }
            guard received > 0 else { continue }
            let text = String(decoding: buffer[0..<received], as: UTF8.self)
            if let candidate = parse(text), byHost[candidate.host] == nil {
                byHost[candidate.host] = candidate
            }
        }
        return Array(byHost.values)
    }

    /// Parser tolerante de uma resposta SSDP (texto HTTP-like, `header: valor` por linha).
    /// Nunca lança. `nil` se não for uma TV Samsung ou faltar `LOCATION`.
    static func parse(_ text: String) -> DiscoveredTV? {
        var headers: [String: String] = [:]
        for line in text.split(separator: "\r\n") {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[line.startIndex..<colon].trimmingCharacters(in: .whitespaces).uppercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[key] = value
        }
        guard let server = headers["SERVER"], server.lowercased().contains("samsung") else { return nil }
        guard let location = headers["LOCATION"], let url = URL(string: location), let host = url.host else {
            return nil
        }
        return DiscoveredTV(host: host, port: url.port ?? 80)
    }
}
