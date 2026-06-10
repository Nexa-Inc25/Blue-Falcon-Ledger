import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

/// Bytes + name of a file the user picked. Type is inferred downstream from the name.
struct ImportedFile: Identifiable {
    let id = UUID()
    let data: Data
    let fileName: String
}

extension View {
    /// Present the system file importer for PDFs and images, returning the bytes.
    /// Reads inside a security scope with a file coordinator so it works for iCloud/Files
    /// and for the "Designed for iPad" app running on macOS. Surfaces a message on failure
    /// instead of silently doing nothing. `onError` runs before `onPick` so existing
    /// trailing-closure call sites keep binding to `onPick`.
    func importFile(isPresented: Binding<Bool>,
                    onError: ((String) -> Void)? = nil,
                    onPick: @escaping (ImportedFile) -> Void) -> some View {
        fileImporter(
            isPresented: isPresented,
            allowedContentTypes: [.pdf, .image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .failure(let error):
                onError?("Couldn't open that file: \(error.localizedDescription)")
            case .success(let urls):
                guard let url = urls.first else { return }
                if let file = ImportedFile.read(from: url) {
                    onPick(file)
                } else {
                    onError?("Couldn't read \"\(url.lastPathComponent)\". Try moving it to Files or your Photos, then upload again.")
                }
            }
        }
    }
}

extension ImportedFile {
    /// Read a user-selected URL into memory, holding the security scope and using a file
    /// coordinator (handles iCloud/provider files and macOS sandboxing).
    static func read(from url: URL) -> ImportedFile? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        var coordinatorError: NSError?
        var result: ImportedFile?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinatorError) { readURL in
            if let data = try? Data(contentsOf: readURL) {
                result = ImportedFile(data: data, fileName: readURL.lastPathComponent)
            }
        }
        // Fall back to a direct read if coordination didn't yield data.
        if result == nil, let data = try? Data(contentsOf: url) {
            result = ImportedFile(data: data, fileName: url.lastPathComponent)
        }
        return result
    }
}

/// Whether this device actually has a camera (false on Simulator). Use to gate the
/// "Take Photo" option so it only appears on real hardware.
@MainActor
var cameraIsAvailable: Bool {
    UIImagePickerController.isSourceTypeAvailable(.camera)
}

/// Full-screen camera capture that yields an `ImportedFile` (JPEG). Present as a sheet.
struct CameraPicker: UIViewControllerRepresentable {
    let onCapture: (ImportedFile) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.85) {
                parent.onCapture(ImportedFile(data: data, fileName: "photo-\(UUID().uuidString.prefix(6)).jpg"))
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

/// A photo-library picker button that yields an `ImportedFile` (for stub photos).
struct PhotoImportButton: View {
    let title: String
    let onPick: (ImportedFile) -> Void
    @State private var selection: PhotosPickerItem?

    var body: some View {
        PhotosPicker(selection: $selection, matching: .images) {
            Label(title, systemImage: "photo.on.rectangle")
        }
        .onChange(of: selection) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    onPick(ImportedFile(data: data, fileName: "photo-\(UUID().uuidString.prefix(6)).jpg"))
                }
                selection = nil
            }
        }
    }
}
