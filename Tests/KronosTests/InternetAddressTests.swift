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

        let ipv6Addresses = [
            "::",
            "::1",
            "2001:db8::1",
            "fe80::1",
            "ff02::1",
            "ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff",
            "::ffff:255.255.255.255",
        ]
        for ip in ipv6Addresses {
            var address = sockaddr_in6()
            address.sin6_family = sa_family_t(AF_INET6)
            XCTAssertEqual(inet_pton(AF_INET6, ip, &address.sin6_addr), 1, "Failed to parse \(ip)")

            let internetAddress = InternetAddress.ipv6(address)
            XCTAssertEqual(internetAddress.host, legacyHost(internetAddress), "Mismatch for \(ip)")
            XCTAssertEqual(internetAddress.host, ip)
        }
    }

    /// `host` force-unwraps `inet_ntop`, which can only fail with `ENOSPC` (output longer than the
    /// buffer). These max-length inputs prove the buffers are sized so that failure can't happen, so
    /// the force-unwrap never traps and `host` is never nil.
    func testHostIsNonNilAtBufferSizeBoundary() {
        // Longest IPv4 text form is 15 chars + NUL == INET_ADDRSTRLEN (16), the tightest buffer.
        let ipv4Max = makeIPv4("255.255.255.255")
        XCTAssertNotNil(ipv4Max.host)
        XCTAssertEqual(ipv4Max.host, "255.255.255.255")
        XCTAssertEqual(ipv4Max.host?.count, Int(INET_ADDRSTRLEN) - 1)

        // Longest text form inet_ntop emits for IPv6 (all groups set) is 39 chars, within
        // INET6_ADDRSTRLEN (46); confirm the conversion still succeeds at that extreme.
        let ipv6Max = makeIPv6("ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff")
        XCTAssertNotNil(ipv6Max.host)
        XCTAssertEqual(ipv6Max.host, "ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff")
    }

    func testEqualityComparesByHost() {
        XCTAssertEqual(makeIPv4("192.168.1.1"), makeIPv4("192.168.1.1"))
        XCTAssertNotEqual(makeIPv4("192.168.1.1"), makeIPv4("192.168.1.2"))
        XCTAssertNotEqual(makeIPv4("127.0.0.1"), makeIPv6("::1"))
    }

    func testHashingMatchesHost() {
        XCTAssertEqual(makeIPv4("10.0.0.1").hashValue, makeIPv4("10.0.0.1").hashValue)
        let unique: Set<InternetAddress> = [
            makeIPv4("10.0.0.1"),
            makeIPv4("10.0.0.1"),
            makeIPv4("10.0.0.2"),
            makeIPv6("::1"),
        ]
        XCTAssertEqual(unique.count, 3)
    }

    func testInitFromDataRoundTripsIPv4() {
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        XCTAssertEqual(inet_pton(AF_INET, "10.20.30.40", &address.sin_addr), 1)
        let data = Data(bytes: &address, count: MemoryLayout<sockaddr_in>.size) as NSData

        let parsed = InternetAddress(dataWithSockAddress: data)
        XCTAssertEqual(parsed?.host, "10.20.30.40")
        XCTAssertEqual(parsed?.family, PF_INET)
    }

    func testInitFromDataRoundTripsIPv6() {
        var address = sockaddr_in6()
        address.sin6_family = sa_family_t(AF_INET6)
        XCTAssertEqual(inet_pton(AF_INET6, "2001:db8::dead:beef", &address.sin6_addr), 1)
        let data = Data(bytes: &address, count: MemoryLayout<sockaddr_in6>.size) as NSData

        let parsed = InternetAddress(dataWithSockAddress: data)
        XCTAssertEqual(parsed?.host, "2001:db8::dead:beef")
        XCTAssertEqual(parsed?.family, PF_INET6)
    }

    func testInitFromDataReturnsNilForUnsupportedFamily() {
        var storage = sockaddr_storage()
        storage.ss_family = sa_family_t(AF_UNIX)
        let data = Data(bytes: &storage, count: MemoryLayout<sockaddr_storage>.size) as NSData

        XCTAssertNil(InternetAddress(dataWithSockAddress: data))
    }

    func testAddressDataEncodesPortAndRoundTrips() {
        let original = makeIPv4("203.0.113.7")
        let data = original.addressData(withPort: 123) as Data

        var parsed = sockaddr_in()
        _ = withUnsafeMutableBytes(of: &parsed) {
            data.copyBytes(to: $0, count: MemoryLayout<sockaddr_in>.size)
        }
        XCTAssertEqual(UInt16(bigEndian: parsed.sin_port), 123)

        let roundTripped = InternetAddress(dataWithSockAddress: data as NSData)
        XCTAssertEqual(roundTripped?.host, "203.0.113.7")
    }

    private func makeIPv4(_ ip: String) -> InternetAddress {
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        precondition(inet_pton(AF_INET, ip, &address.sin_addr) == 1, "invalid IPv4 \(ip)")
        return .ipv4(address)
    }

    private func makeIPv6(_ ip: String) -> InternetAddress {
        var address = sockaddr_in6()
        address.sin6_family = sa_family_t(AF_INET6)
        precondition(inet_pton(AF_INET6, ip, &address.sin6_addr) == 1, "invalid IPv6 \(ip)")
        return .ipv6(address)
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
