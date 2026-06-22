import XCTest
@testable import Kronos

@MainActor
final class NTPClientTests: XCTestCase {

    func testQueryIP() throws {
        let expectation = self.expectation(description: "NTPClient queries single IPs")
        var unreachable = false

        DNSResolver.resolve(host: "time.apple.com") { addresses in
            guard let ip = addresses.first else {
                unreachable = true
                expectation.fulfill()
                return
            }

            NTPClient().query(ip: ip, version: 3, numberOfSamples: 1) { PDU in
                guard let PDU else {
                    unreachable = true
                    expectation.fulfill()
                    return
                }

                XCTAssertGreaterThanOrEqual(PDU.version, 3)
                XCTAssertTrue(PDU.isValidResponse())
                expectation.fulfill()
            }
        }

        self.waitForExpectations(timeout: 10)
        try XCTSkipIf(unreachable, "DNS/NTP unreachable (network/UDP 123 blocked?)")
    }

    func testQueryPool() throws {
        let expectation = self.expectation(description: "Offset from ref clock to local clock are accurate")
        var unreachable = false

        NTPClient().query(pool: "0.pool.ntp.org", numberOfSamples: 1, maximumServers: 1) { offset, _, _ in
            NTPClient().query(pool: "0.pool.ntp.org", numberOfSamples: 1, maximumServers: 1)
            { offset2, _, _ in
                guard let offset, let offset2 else {
                    unreachable = true
                    expectation.fulfill()
                    return
                }
                XCTAssertLessThan(abs(offset - offset2), 0.10)
                expectation.fulfill()
            }
        }

        self.waitForExpectations(timeout: 10)
        try XCTSkipIf(unreachable, "NTP query returned no offset (network/UDP 123 blocked?)")
    }

    func testQueryPoolWithIPv6() throws {
        let expectation = self.expectation(description: "NTPClient queries a pool that supports IPv6")
        var unreachable = false

        NTPClient().query(pool: "2.pool.ntp.org", numberOfSamples: 1, maximumServers: 1) { offset, _, _ in
            unreachable = offset == nil
            expectation.fulfill()
        }

        self.waitForExpectations(timeout: 10)
        try XCTSkipIf(unreachable, "NTP query returned no offset (network/UDP 123 blocked?)")
    }
}
