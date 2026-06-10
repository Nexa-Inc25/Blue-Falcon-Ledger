import XCTest
@testable import BFC

/// Tests for the retriever's pure helpers — tokenizing, query expansion, rate detection.
final class RetrieverTests: XCTestCase {

    func testTokenizeDropsStopwordsAndShortTokens() {
        let tokens = ChunkRetriever.tokenize("What is the OT rate?")
        XCTAssertFalse(tokens.contains("is"))
        XCTAssertFalse(tokens.contains("the"))
        XCTAssertTrue(tokens.contains("ot"))
        XCTAssertTrue(tokens.contains("rate"))
    }

    func testExpandSingularPlural() {
        XCTAssertTrue(ChunkRetriever.expand(["meals"]).contains("meal"))
        XCTAssertTrue(ChunkRetriever.expand(["hour"]).contains("hours"))
    }

    func testExpandLinemanShorthand() {
        XCTAssertTrue(ChunkRetriever.expand(["ot"]).contains("overtime"))
        XCTAssertTrue(ChunkRetriever.expand(["dt"]).contains("double"))
        XCTAssertTrue(ChunkRetriever.expand(["foreman"]).contains("classification"))
    }

    func testIsRateQuery() {
        XCTAssertTrue(ChunkRetriever.isRateQuery("what's the foreman rate of pay"))
        XCTAssertTrue(ChunkRetriever.isRateQuery("how much per diem do I get"))
        XCTAssertFalse(ChunkRetriever.isRateQuery("who is the bargaining agent"))
    }

    func testBenefitsAreTreatedAsPayQuestions() {
        XCTAssertTrue(ChunkRetriever.isRateQuery("what's the NEAP pension contribution"))
        XCTAssertTrue(ChunkRetriever.isRateQuery("how much health and welfare do they pay"))
        XCTAssertTrue(ChunkRetriever.expand(["neap"]).contains("pension"))
        XCTAssertTrue(ChunkRetriever.expand(["benefits"]).contains("welfare"))
    }

    func testBaseHeadingStripsWindowSuffix() {
        XCTAssertEqual(
            ChunkRetriever.baseHeading("APPENDIX A — WAGE SCHEDULE (part 2)"),
            "APPENDIX A — WAGE SCHEDULE"
        )
        XCTAssertEqual(ChunkRetriever.baseHeading("ARTICLE 5"), "ARTICLE 5")
    }

    func testLooksLikeRateTable() {
        let wage = AgreementChunk(order: 0, heading: "APPENDIX A — WAGE SCHEDULE",
                                  text: "Journeyman lineman 58.00")
        XCTAssertTrue(ChunkRetriever.looksLikeRateTable(wage))

        let bodyTable = AgreementChunk(order: 1, heading: "Rates",
                                       text: "Foreman 1.15 of JL and Operator 0.90 of JL")
        XCTAssertTrue(ChunkRetriever.looksLikeRateTable(bodyTable))

        let recognition = AgreementChunk(order: 2, heading: "ARTICLE 1 — RECOGNITION",
                                         text: "The Employer recognizes the Union.")
        XCTAssertFalse(ChunkRetriever.looksLikeRateTable(recognition))
    }
}
