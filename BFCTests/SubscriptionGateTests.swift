import XCTest
@testable import BFC

/// Tests the cost-based gating rule: only BFC Cloud (our proxy) is metered; on-device and
/// bring-your-own-key providers are never gated.
@MainActor
final class SubscriptionGateTests: XCTestCase {

    func testOnlyBFCCloudIsMetered() {
        let subs = SubscriptionService.shared
        XCTAssertTrue(subs.isMetered(.bfcCloud))
        XCTAssertFalse(subs.isMetered(.appleOnDevice))
        XCTAssertFalse(subs.isMetered(.claude))
        XCTAssertFalse(subs.isMetered(.openai))
        XCTAssertFalse(subs.isMetered(.grok))
    }

    func testNonMeteredProvidersAreAlwaysAllowed() {
        let subs = SubscriptionService.shared
        // On-device and BYO-key never hit the paywall, regardless of Pro/credits.
        XCTAssertTrue(subs.cloudAllowed(provider: .appleOnDevice))
        XCTAssertTrue(subs.cloudAllowed(provider: .claude))
        XCTAssertTrue(subs.cloudAllowed(provider: .grok))
    }

    func testBFCCloudNotGatedWhenNoPlansAvailable() {
        // No StoreKit products load in tests, so there's nothing to buy — must NOT be gated.
        let subs = SubscriptionService.shared
        XCTAssertTrue(subs.products.isEmpty)
        XCTAssertTrue(subs.cloudAllowed(provider: .bfcCloud))
    }
}
