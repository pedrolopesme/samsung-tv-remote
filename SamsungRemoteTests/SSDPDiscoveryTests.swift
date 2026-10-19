import Foundation
import Testing
@testable import SamsungRemote

@Suite("Descoberta SSDP (spec 0003)")
struct SSDPDiscoveryTests {
    @Test("Resposta real da Samsung (porta 7678, serviço principal)")
    func parsesSamsungPrimaryService() throws {
        let tv = try #require(SSDPDiscovery.parse(SSDPFixtures.samsungPrimary))
        #expect(tv.host == "192.168.68.109")
        #expect(tv.port == 7678)
    }

    @Test("Resposta real da Samsung (porta 9197, DLNA MediaRenderer) — mesmo host")
    func parsesSamsungMediaRenderer() throws {
        let tv = try #require(SSDPDiscovery.parse(SSDPFixtures.samsungMediaRenderer))
        #expect(tv.host == "192.168.68.109")
        #expect(tv.port == 9197)
    }

    @Test("Resposta do serviço MDX do Netflix (mesma TV) é ignorada — SERVER sem 'samsung'")
    func ignoresNonSamsungServer() {
        #expect(SSDPDiscovery.parse(SSDPFixtures.netflixMDX) == nil)
    }

    @Test("Resposta do roteador (TP-LINK) é ignorada")
    func ignoresRouterResponse() {
        #expect(SSDPDiscovery.parse(SSDPFixtures.tpLinkRouter) == nil)
    }

    @Test("Resposta sem LOCATION não derruba o parser")
    func handlesMissingLocation() {
        let text = "HTTP/1.1 200 OK\r\nSERVER: Samsung-Linux/4.1\r\nST: upnp:rootdevice\r\n\r\n"
        #expect(SSDPDiscovery.parse(text) == nil)
    }

    @Test("Resposta vazia/malformada não derruba o parser")
    func handlesGarbage() {
        #expect(SSDPDiscovery.parse("") == nil)
        #expect(SSDPDiscovery.parse("isso não é SSDP de jeito nenhum") == nil)
    }
}

private enum SSDPFixtures {
    /// Capturado ao vivo contra a AU8000 (192.168.68.109), 2026-10-19 — ver spec 0003.
    static let samsungPrimary = """
    HTTP/1.1 200 OK\r
    CACHE-CONTROL: max-age=1800\r
    LOCATION: http://192.168.68.109:7678/nservice/\r
    SERVER: Samsung-Linux/4.1, UPnP/1.0, Samsung_UPnP_SDK/1.0\r
    ST: upnp:rootdevice\r
    USN: uuid:827c17fe-2309-4b24-a117-38cb94ae3fa3::upnp:rootdevice\r
    Content-Length: 0\r
    BOOTID.UPNP.ORG: 6\r
    \r
    """

    static let samsungMediaRenderer = """
    HTTP/1.1 200 OK\r
    CACHE-CONTROL: max-age=1800\r
    LOCATION: http://192.168.68.109:9197/dmr\r
    SERVER: Samsung-Linux/4.1, UPnP/1.0, Samsung_UPnP_SDK/1.0\r
    ST: upnp:rootdevice\r
    USN: uuid:2ba8b004-b48f-4628-a77f-9f1733d8a2b6::upnp:rootdevice\r
    Content-Length: 0\r
    BOOTID.UPNP.ORG: 4\r
    \r
    """

    static let netflixMDX = """
    HTTP/1.1 200 OK\r
    CACHE-CONTROL: max-age=1800\r
    LOCATION: http://192.168.68.109:9080\r
    SERVER: Linux/4.1.10, UPnP/1.0, Portable SDK for UPnP devices\r
    X-User-Agent: NRDP MDX\r
    ST: upnp:rootdevice\r
    USN: uuid:SSTV-NL21-0000000000000001100005::upnp:rootdevice\r
    \r
    """

    static let tpLinkRouter = """
    HTTP/1.1 200 OK\r
    CACHE-CONTROL: max-age=120\r
    ST: upnp:rootdevice\r
    USN: uuid:e4c797e0-82ce-4f84-b56d-085d9d77c8cd::upnp:rootdevice\r
    SERVER: TP-LINK/TP-LINK UPnP/1.1 MiniUPnPd/1.8\r
    LOCATION: http://192.168.68.1:1900/rootDesc.xml\r
    \r
    """
}
