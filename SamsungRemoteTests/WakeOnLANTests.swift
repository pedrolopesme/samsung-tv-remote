import Testing
@testable import SamsungRemote

@Suite("Wake-on-LAN")
struct WakeOnLANTests {
    @Test("Aceita formatos comuns de MAC", arguments: [
        "00:11:22:AA:BB:CC",
        "00-11-22-aa-bb-cc",
        "001122AABBCC",
        "0011.22aa.bbcc",
    ])
    func parsesMAC(mac: String) throws {
        #expect(try WakeOnLAN.macBytes(mac) == [0x00, 0x11, 0x22, 0xAA, 0xBB, 0xCC])
    }

    @Test("Rejeita MAC inválido", arguments: ["", "00:11:22", "GG:11:22:33:44:55", "00:11:22:33:44:55:66"])
    func rejectsInvalidMAC(mac: String) {
        #expect(throws: TVConnectionError.invalidMACAddress) {
            try WakeOnLAN.macBytes(mac)
        }
    }

    @Test("Magic packet tem 102 bytes: 6×FF + 16×MAC")
    func magicPacket() throws {
        let packet = try WakeOnLAN.magicPacket(mac: "00:11:22:AA:BB:CC")
        #expect(packet.count == 102)
        #expect(Array(packet.prefix(6)) == [UInt8](repeating: 0xFF, count: 6))
        for repetition in 0..<16 {
            let start = 6 + repetition * 6
            #expect(Array(packet[start..<start + 6]) == [0x00, 0x11, 0x22, 0xAA, 0xBB, 0xCC])
        }
    }

    @Test("Formata MAC em maiúsculas com dois-pontos")
    func formatsMAC() {
        #expect(WakeOnLAN.formatted("001122aabbcc") == "00:11:22:AA:BB:CC")
        #expect(WakeOnLAN.formatted("xyz") == nil)
    }
}
