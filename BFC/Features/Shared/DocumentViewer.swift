import SwiftUI
import PDFKit

/// Renders a stored document (PDF or image) from raw bytes. Used to view credentials and
/// any other uploaded file in-app.
struct DocumentViewer: View {
    let data: Data?
    let fileName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let data, PDFDocument(data: data) != nil {
                    PDFKitView(data: data)
                } else if let data, let image = UIImage(data: data) {
                    ScrollView([.horizontal, .vertical]) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    EmptyHint(systemImage: "doc.questionmark",
                              title: "Nothing to show",
                              message: "This credential doesn't have a file attached yet.")
                }
            }
            .bfcBackground()
            .navigationTitle(fileName.isEmpty ? "Document" : fileName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Theme.accent)
                }
            }
        }
    }
}

/// PDFKit's `PDFView` wrapped for SwiftUI.
private struct PDFKitView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.backgroundColor = .black
        view.document = PDFDocument(data: data)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document == nil { view.document = PDFDocument(data: data) }
    }
}
