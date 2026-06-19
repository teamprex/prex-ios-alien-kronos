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

    /// `host` was migrated off the deprecated array-based `String(cString:)` overload to the
    /// `UnsafePointer<CChar>` overload. This proves the migration produced identical output.
    @available(*, deprecated, message: "Compares against the deprecated decoding path on purpose.")
    func testHostMatchesLegacyCStringDecoding() {
        let ipv4Addresses = ["0.0.0.0", "127.0.0.1", "192.168.1.1", "255.255.255.255", "8.8.8.8"]
        for ip in ipv4Addresses {
            var address = sockaddr_in()
            address.sin_family = sa_family_t(AF_INET)
            XCTAssertEqual(inet_pton(AF_INET, ip, &address.sin_addr), 1, "Failed to parse \(ip)")

            let internetAddress = InternetAddress.ipv4(address)
            XCTAssertEqual(internetAddress.host, legacyHost(internetAddress), "Mismatch for \(ip)")
            XCTAssertEqual(internetAddress.host, ip)
        }

        let ipv6Addresses = ["::", "::1", "2001:db8::1", "fe80::1", "ff02::1"]
        for ip in ipv6Addresses {
            var address = sockaddr_in6()
            address.sin6_family = sa_family_t(AF_INET6)
            XCTAssertEqual(inet_pton(AF_INET6, ip, &address.sin6_addr), 1, "Failed to parse \(ip)")

            let internetAddress = InternetAddress.ipv6(address)
            XCTAssertEqual(internetAddress.host, legacyHost(internetAddress), "Mismatch for \(ip)")
            XCTAssertEqual(internetAddress.host, ip)
        }
    }

    /// Re-implements the pre-migration `host` getter verbatim using the deprecated array-based
    /// `String(cString:)` overload, so the test can assert behavioral parity with the new path.
    @available(*, deprecated, message: "Uses the deprecated String(cString: [CChar]) overload on purpose.")
    private func legacyHost(_ address: InternetAddress) -> String? {
        switch address {
        case .ipv6(var addr):
            var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
            inet_ntop(AF_INET6, &addr.sin6_addr, &buffer, socklen_t(INET6_ADDRSTRLEN))
            return String(cString: buffer)

        case .ipv4(var addr):
            var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            inet_ntop(AF_INET, &addr.sin_addr, &buffer, socklen_t(INET_ADDRSTRLEN))
            return String(cString: buffer)
        }
    }
}
