import Darwin
import Foundation

/// Liga a TV a partir do standby enviando um "magic packet" por broadcast UDP.
///
/// Requer, na TV: Configurações › Geral › Rede › Configurações avançadas ›
/// "Ligar com dispositivo móvel" ativado. Ver `docs/tv/UN65AU8000GXZD.md`.
enum WakeOnLAN {
    /// Normaliza "80:47:86:98:6E:C0", "80-47-86-98-6e-c0" ou "804786986EC0" em 6 bytes.
    static func macBytes(_ mac: String) throws -> [UInt8] {
        let hex = mac.filter { !":-. ".contains($0) }
        guard hex.count == 12, hex.allSatisfy(\.isHexDigit) else {
            throw TVConnectionError.invalidMACAddress
        }
        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else {
                throw TVConnectionError.invalidMACAddress
            }
            bytes.append(byte)
            index = next
        }
        return bytes
    }

    /// 6 × 0xFF seguidos de 16 repetições do MAC = 102 bytes.
    static func magicPacket(mac: String) throws -> [UInt8] {
        let address = try Self.macBytes(mac)
        var packet = [UInt8](repeating: 0xFF, count: 6)
        for _ in 0..<16 { packet.append(contentsOf: address) }
        return packet
    }

    /// Formata como "80:47:86:98:6E:C0".
    static func formatted(_ mac: String) -> String? {
        guard let bytes = try? macBytes(mac) else { return nil }
        return bytes.map { String(format: "%02X", $0) }.joined(separator: ":")
    }

    static func send(mac: String, broadcastAddress: String = "255.255.255.255", port: UInt16 = 9) throws {
        let packet = try magicPacket(mac: mac)

        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
        defer { close(fd) }

        var enable: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &enable, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        address.sin_addr.s_addr = inet_addr(broadcastAddress)

        let sent = packet.withUnsafeBytes { buffer in
            withUnsafePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                    sendto(fd, buffer.baseAddress, buffer.count, 0, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent == packet.count else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
    }
}
