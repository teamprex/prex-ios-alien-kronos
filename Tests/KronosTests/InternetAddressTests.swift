import XCTest
@testable import Kronos

final class InternetAddressTests: XCTestCase {

    func testIPv4Host() {
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        XCTAssertEqual(inet_pton(AF_INET, "127.0.0.1", &address.sin_addr), 1)

        let internetAddress = InternetAddress.ipv4(address)
        XCTAssertEqual(internetAddress.host, "127.0.0.1")
        XCTAssertEqual(internetAddress.family, PF_INET)
    }

    func testIPv6Host() {
        var address = sockaddr_in6()
        address.sin6_family = sa_family_t(AF_INET6)
        XCTAssertEqual(inet_pton(AF_INET6, "2001:db8::1", &address.sin6_addr), 1)

        let internetAddress = InternetAddress.ipv6(address)
        XCTAssertEqual(internetAddress.host, "2001:db8::1")
        XCTAssertEqual(internetAddress.family, PF_INET6)
    }
}
