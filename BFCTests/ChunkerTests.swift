import XCTest
@testable import BFC

/// Tests for the agreement chunker — the front of the RAG pipeline.
final class ChunkerTests: XCTestCase {

    func testSplitsByArticleHeadings() {
        let text = """
        ARTICLE 1 — RECOGNITION
        The Employer recognizes the Union.

        ARTICLE 5 — OVERTIME
        Work over eight hours is time and one half.

        ARTICLE 8 — PER DIEM
        Per diem is one hundred twenty dollars per day.
        """
        let chunks = AgreementChunker.chunk(text)
        XCTAssertGreaterThanOrEqual(chunks.count, 3)
        let headings = chunks.map(\.heading)
        XCTAssertTrue(headings.contains { $0.contains("OVERTIME") })
        XCTAssertTrue(headings.contains { $0.contains("PER DIEM") })
    }

    func testLongSectionGetsWindowed() {
        let bigBody = Array(repeating: "This clause repeats to exceed the window.", count: 80)
            .joined(separator: " ")
        let text = "ARTICLE 5 — OVERTIME\n\(bigBody)"
        let chunks = AgreementChunker.chunk(text)
        XCTAssertGreaterThan(chunks.count, 1, "A long section should split into windows")
        XCTAssertTrue(chunks.allSatisfy { $0.text.count <= AgreementChunker.maxChunkChars + 50 })
        XCTAssertTrue(chunks.contains { $0.heading.contains("part") })
    }

    func testEmptyTextReturnsNoChunks() {
        XCTAssertTrue(AgreementChunker.chunk("   \n  ").isEmpty)
    }

    func testUnstructuredTextStillChunks() {
        let text = "Just a blob of contract language with no headings at all. " +
                   String(repeating: "More text. ", count: 5)
        let chunks = AgreementChunker.chunk(text)
        XCTAssertFalse(chunks.isEmpty)
    }
}
