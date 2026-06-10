import XCTest
@testable import BFC

/// Tests for parsing the LLM's pay-audit verdict block. This drives the colored verdict
/// card and the "amount owed" figure, so it must be exact.
@MainActor
final class AnalysisParsingTests: XCTestCase {

    func testParsesShortedVerdictWithAmount() {
        let raw = """
        You worked 4 hours of double time but got paid straight time. That's a shortfall.

        ===VERDICT===
        STATUS: SHORTED
        HEADLINE: Shorted 4 hrs double time — about $184 owed
        AMOUNT_OWED: 184
        ===END===
        """
        let result = AnalysisEngine.parse(raw)
        XCTAssertEqual(result.verdict, .shorted)
        XCTAssertEqual(result.headline, "Shorted 4 hrs double time — about $184 owed")
        XCTAssertEqual(result.amountOwed, Decimal(184))
        XCTAssertTrue(result.detail.contains("double time"))
        XCTAssertFalse(result.detail.contains("VERDICT"), "Machine block should be stripped from detail")
    }

    func testParsesLooksGoodWithNoneAmount() {
        let raw = """
        Everything checks out.

        ===VERDICT===
        STATUS: LOOKS_GOOD
        HEADLINE: Pay matches the agreement
        AMOUNT_OWED: NONE
        ===END===
        """
        let result = AnalysisEngine.parse(raw)
        XCTAssertEqual(result.verdict, .looksGood)
        XCTAssertNil(result.amountOwed)
    }

    func testParsesAmountWithDollarSignAndComma() {
        let raw = """
        Big miss here.

        ===VERDICT===
        STATUS: SHORTED
        HEADLINE: Owed back pay
        AMOUNT_OWED: $1,250.50
        ===END===
        """
        let result = AnalysisEngine.parse(raw)
        XCTAssertEqual(result.amountOwed, Decimal(string: "1250.50"))
    }

    func testPlainTextWithNoBlockIsNeedsInfo() {
        let result = AnalysisEngine.parse("I couldn't find the rate in the sections I pulled up.")
        XCTAssertEqual(result.verdict, .needsInfo)
        XCTAssertTrue(result.detail.contains("couldn't find"))
    }
}
