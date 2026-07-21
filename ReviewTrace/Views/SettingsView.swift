import SwiftUI

struct SettingsView: View {
    @Environment(ReviewTraceStore.self) private var store
    @State private var deleteAlert: SettingsDeleteAlert?

    var body: some View {
        let copy = store.copy

        Form {
            Section(copy.general) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(copy.appLanguage)

                    Picker(copy.appLanguage, selection: Binding(
                        get: { store.appLanguage },
                        set: { store.setAppLanguage($0) }
                    )) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(copy.transcriptionLanguageName(language)).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(copy.defaultTranscriptionLanguage)

                    Picker(copy.defaultTranscriptionLanguage, selection: Binding(
                        get: { store.transcriptionLanguage },
                        set: { store.setTranscriptionLanguage($0) }
                    )) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(copy.transcriptionLanguageName(language)).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .disabled(store.isBackgroundWorkActive)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(copy.exportDefaultFormat)
                    Text(copy.shareVideoAndReview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section(copy.privacy) {
                Label(copy.localFileStorage, systemImage: "internaldrive")
                Text(copy.privacyExplanation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Label(copy.speechRecognitionPrivacy, systemImage: "waveform.badge.mic")
                Text(copy.speechRecognitionPrivacyExplanation)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(copy.exportStyle) {
                Label(copy.shareVideoAndReview, systemImage: "paperplane")
                Label(copy.readableTimeline, systemImage: "text.alignleft")
                Label(copy.originalTimeline, systemImage: "text.badge.checkmark")
                Label(copy.structuredJSON, systemImage: "curlybraces")
                Label(copy.subtitleExports, systemImage: "captions.bubble")
            }

            Section(copy.dataManagement) {
                Button(role: .destructive) {
                    deleteAlert = .confirmDeleteAll
                } label: {
                    Label(copy.deleteAllRecordings, systemImage: "trash")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(ReviewTraceStyle.screenBackground.ignoresSafeArea())
        .navigationTitle(copy.settingsTitle)
        .alert(item: $deleteAlert) { alert in
            switch alert {
            case .confirmDeleteAll:
                Alert(
                    title: Text(copy.deleteAllConfirmTitle),
                    message: Text(copy.deleteAllConfirmMessage),
                    primaryButton: .destructive(Text(copy.deleteAllRecordings)) {
                        if store.deleteAllData() {
                            DispatchQueue.main.async {
                                deleteAlert = .deleteCompleted
                            }
                        }
                    },
                    secondaryButton: .cancel(Text(copy.cancel))
                )
            case .deleteCompleted:
                Alert(
                    title: Text(copy.deleteCompletedTitle),
                    message: Text(copy.deleteAllCompletedMessage),
                    dismissButton: .default(Text(copy.ok))
                )
            }
        }
    }
}

private enum SettingsDeleteAlert: Identifiable {
    case confirmDeleteAll
    case deleteCompleted

    var id: String {
        switch self {
        case .confirmDeleteAll: "confirmDeleteAll"
        case .deleteCompleted: "deleteCompleted"
        }
    }
}
