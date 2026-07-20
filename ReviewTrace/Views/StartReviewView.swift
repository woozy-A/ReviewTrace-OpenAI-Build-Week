import CoreTransferable
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct ImportVideoView: View {
    @Environment(ReviewTraceStore.self) private var store
    @State private var selectedVideoItem: PhotosPickerItem?
    @State private var isImporting = false

    var body: some View {
        let copy = store.copy

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(copy.importVideoTitle)
                        .font(.largeTitle.bold())
                    Text(copy.importVideoSubtitle)
                        .foregroundStyle(.secondary)
                }

                PhotosPicker(selection: $selectedVideoItem, matching: .videos) {
                    Label(isImporting ? copy.importing : copy.selectVideo, systemImage: "video.badge.plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ReviewTracePrimaryButtonStyle())
                .disabled(isImporting || store.isBackgroundWorkActive)

                VStack(alignment: .leading, spacing: 12) {
                    Text(copy.howToRecord)
                        .font(.headline)
                    ImportInstructionRow(number: 1, text: copy.recordStep1)
                    ImportInstructionRow(number: 2, text: copy.recordStep2)
                    ImportInstructionRow(number: 3, text: copy.recordStep3)
                    ImportInstructionRow(number: 4, text: copy.recordStep4)
                    ImportInstructionRow(number: 5, text: copy.recordStep5)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: ReviewTraceStyle.panelCornerRadius))

                Label(copy.importPrivacyCopy, systemImage: "lock.shield")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle(copy.importExistingRecording)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedVideoItem) { _, newItem in
            guard let newItem else { return }
            importVideo(newItem)
        }
    }

    private func importVideo(_ item: PhotosPickerItem) {
        Task {
            isImporting = true
            defer {
                isImporting = false
                selectedVideoItem = nil
            }

            do {
                if let importedVideo = try await item.loadTransferable(type: ImportedVideo.self) {
                    await store.importExistingRecordingFile(
                        at: importedVideo.fileURL,
                        ownsSourceFile: true
                    )
                }
            } catch {
                store.errorMessage = error.localizedDescription
            }
        }
    }
}

private struct ImportInstructionRow: View {
    var number: Int
    var text: String

    var body: some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.caption.bold().monospacedDigit())
                .frame(width: 24, height: 24)
                .background(.indigo.opacity(0.14), in: RoundedRectangle(cornerRadius: ReviewTraceStyle.badgeCornerRadius))
                .foregroundStyle(.indigo)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
}

private struct ImportedVideo: Transferable {
    let fileURL: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            let fileExtension = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let copyURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(fileExtension)

            if FileManager.default.fileExists(atPath: copyURL.path) {
                try FileManager.default.removeItem(at: copyURL)
            }
            try FileManager.default.copyItem(at: received.file, to: copyURL)
            return ImportedVideo(fileURL: copyURL)
        }
    }
}

#Preview {
    NavigationStack {
        ImportVideoView()
            .environment(ReviewTraceStore())
    }
}
