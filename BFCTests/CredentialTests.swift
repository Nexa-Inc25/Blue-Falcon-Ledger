import XCTest
@testable import BFC

/// Tests for credential expiration status — drives the colored badges and reminders.
final class CredentialTests: XCTestCase {

    private func credential(expiringInDays days: Int?) -> Credential {
        let exp = days.map { Calendar.current.date(byAdding: .day, value: $0, to: .now)! }
        return Credential(kind: .firstAidCPR, expirationDate: exp)
    }

    func testNoExpirationIsNoExpiry() {
        if case .noExpiry = credential(expiringInDays: nil).status() { } else {
            XCTFail("Expected .noExpiry")
        }
    }

    func testFarFutureIsValid() {
        if case .valid(let d) = credential(expiringInDays: 60).status() {
            XCTAssertEqual(d, 60)
        } else { XCTFail("Expected .valid") }
    }

    func testWithinThirtyDaysIsExpiringSoon() {
        if case .expiringSoon(let d) = credential(expiringInDays: 10).status() {
            XCTAssertEqual(d, 10)
        } else { XCTFail("Expected .expiringSoon") }
    }

    func testExactlyThirtyDaysIsExpiringSoon() {
        if case .expiringSoon = credential(expiringInDays: 30).status() { } else {
            XCTFail("30 days should still be 'expiring soon'")
        }
    }

    func testPastDateIsExpired() {
        if case .expired = credential(expiringInDays: -1).status() { } else {
            XCTFail("Expected .expired")
        }
    }

    func testDisplayNameFallsBackToKind() {
        XCTAssertEqual(Credential(kind: .dotPhysical).displayName, "DOT Physical")
        XCTAssertEqual(Credential(kind: .dotPhysical, title: "My DOT card").displayName, "My DOT card")
    }
}
