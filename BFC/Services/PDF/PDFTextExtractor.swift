import Foundation
import PDFKit
import Vision
import UIKit

/// Pulls all text out of an uploaded document. PDFs first try embedded text (fast,
/// exact); pages with little/no text fall back to Vision OCR (handles scans/photos).
/// Images go straight to OCR.
struct PDFTextExtractor {

    /// Extract text from raw file bytes. `fileName` is used only to guess the type.
    static func extractText(from data: Data, fileName: String) async -> String {
        if fileName.lowercased().hasSuffix(".pdf") || PDFDocument(data: data) != nil {
            return await extractFromPDF(data: data)
        }
        if let image = UIImage(data: data) {
            return await ocr(images: [image])
        }
        return ""
    }

    // MARK: - PDF

    private static func extractFromPDF(data: Data) async -> String {
        guard let doc = PDFDocument(data: data) else { return "" }
        var pieces: [String] = []
        var pagesNeedingOCR: [UIImage] = []

        for index in 0..<doc.pageCount {
            guard let page = doc.page(at: index) else { continue }
            let embedded = page.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            // Heuristic: very little text on a page usually means it's a scanned image.
            if embedded.count > 40 {
                pieces.append(embedded)
            } else if let image = render(page: page) {
                pagesNeedingOCR.append(image)
            }
        }

        if !pagesNeedingOCR.isEmpty {
            let ocrText = await ocr(images: pagesNeedingOCR)
            if !ocrText.isEmpty { pieces.append(ocrText) }
        }
        return pieces.joined(separator: "\n\n")
    }

    /// Render a PDF page to a bitmap for OCR.
    private static func render(page: PDFPage) -> UIImage? {
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        // Upscale a bit so OCR has enough resolution.
        let scale: CGFloat = 2.0
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.cgContext.scaleBy(x: scale, y: scale)
            ctx.cgContext.translateBy(x: 0, y: bounds.height)
            ctx.cgContext.scaleBy(x: 1, y: -1)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
    }

    // MARK: - OCR (Vision)

    private static func ocr(images: [UIImage]) async -> String {
        var results: [String] = []
        for image in images {
            guard let cgImage = image.cgImage else { continue }
            let text = await recognizeText(in: cgImage)
            if !text.isEmpty { results.append(text) }
        }
        return results.joined(separator: "\n\n")
    }

    private static func recognizeText(in cgImage: CGImage) async -> String {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: "")
            }
        }
    }
}
