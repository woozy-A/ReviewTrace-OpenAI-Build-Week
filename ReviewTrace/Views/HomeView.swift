import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @Environment(ReviewTraceStore.self) private var store
    @State private var showsAudioImporter = false
    @State private var isImportingAudio = false
    @State private var showsRecordingGuide = false
    private static let recentReviewLimit = 3

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                spokenLanguagePicker
                primaryActions
                howToRecord
                recentReviews
            }
            .padding()
            .padding(.bottom, 24)
        }
        .background(ReviewTraceStyle.screenBackground.ignoresSafeArea())
        .navigationTitle("ReviewTrace")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var spokenLanguagePicker: some View {
        SpokenLanguagePicker(
            selection: Binding(
                get: { store.transcriptionLanguage },
                set: { store.setTranscriptionLanguage($0) }
            ),
            copy: store.copy
        )
        .disabled(store.isBackgroundWorkActive)
    }

    @ViewBuilder
    private var header: some View {
        let copy = store.copy

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(copy.homeHeroTitle)
                        .font(.system(size: 26, weight: .bold, design: .default))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(copy.homeHeroSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                }

                Spacer(minLength: 12)

                ZStack {
                    RoundedRectangle(cornerRadius: ReviewTraceStyle.controlCornerRadius, style: .continuous)
                        .fill(ReviewTraceStyle.accentColor.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: "waveform")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(ReviewTraceStyle.accentColor)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var primaryActions: some View {
        let copy = store.copy

        VStack(spacing: 12) {
            NavigationLink(value: AppRoute.importVideo) {
                Label(copy.startReview, systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ReviewTracePrimaryButtonStyle())
            .disabled(store.isBackgroundWorkActive)

            Button {
                showsAudioImporter = true
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "waveform.badge.mic")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(ReviewTraceStyle.accentColor)
                        .frame(width: 34, height: 34)
                        .background(ReviewTraceStyle.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: ReviewTraceStyle.badgeCornerRadius, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(isImportingAudio ? copy.importing : copy.importAudioFile)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(copy.importAudioFileDescription)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineSpacing(2)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .reviewTraceCard()
            }
            .buttonStyle(.plain)
            .disabled(isImportingAudio || store.isBackgroundWorkActive)
        }
        .fileImporter(
            isPresented: $showsAudioImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            importAudio(result)
        }
    }

    private func importAudio(_ result: Result<[URL], Error>) {
        Task {
            isImportingAudio = true
            defer { isImportingAudio = false }

            do {
                guard let url = try result.get().first else { return }
                let hasAccess = url.startAccessingSecurityScopedResource()
                defer {
                    if hasAccess {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                await store.importAudioFile(at: url)
            } catch {
                store.errorMessage = error.localizedDescription
            }
        }
    }

    @ViewBuilder
    private var howToRecord: some View {
        let copy = store.copy

        DisclosureGroup(isExpanded: $showsRecordingGuide) {
            VStack(alignment: .leading, spacing: 9) {
                InstructionLine(number: 1, text: copy.quickRecordStep1)
                InstructionLine(number: 2, text: copy.quickRecordStep2)
                InstructionLine(number: 3, text: copy.quickRecordStep3)
            }
            .padding(.top, 10)
        } label: {
            HStack {
                Label(copy.howToRecord, systemImage: "record.circle")
                    .font(.headline)
                Spacer()
            }
        }
        .tint(.primary)
        .padding(14)
        .reviewTraceCard()
    }

    @ViewBuilder
    private var recentReviews: some View {
        let copy = store.copy

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(copy.recentReviewsLimit(Self.recentReviewLimit))
                    .font(.title3.bold())
                Spacer()
            }
            if store.sessions.isEmpty {
                ContentUnavailableView(
                    copy.noReviewsTitle,
                    systemImage: "waveform.badge.mic",
                    description: Text(copy.noReviewsDescription)
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(store.sessions.prefix(Self.recentReviewLimit)) { session in
                        NavigationLink(value: AppRoute.reviewDetail(session.id)) {
                            ReviewRow(session: session, language: store.appLanguage)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

}

struct SpokenLanguagePicker: View {
    @Binding var selection: AppLanguage
    var copy: AppCopy

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(copy.spokenReviewLanguage)
                .font(.headline)

            Picker(copy.spokenReviewLanguage, selection: $selection) {
                ForEach(AppLanguage.allCases) { language in
                    Text(copy.transcriptionLanguageName(language, includesLocale: true))
                        .tag(language)
                }
            }
            .pickerStyle(.segmented)

            Text(copy.spokenReviewLanguageHelp)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .reviewTraceCard()
    }
}

struct ReviewRow: View {
    var session: ReviewSession
    var language: AppLanguage

    var body: some View {
        let copy = AppCopy(language: language)
        let sourceKind = session.resolvedSourceKind

        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: ReviewTraceStyle.controlCornerRadius, style: .continuous)
                    .fill(LinearGradient(colors: iconColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: sourceKind == .audioFile ? "waveform" : "play.rectangle.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(copy.displayTitle(session.title))
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("\(copy.sourceLabel(for: sourceKind)) · \(ReviewTimeFormatter.clock(session.duration)) · \(copy.transcriptCount(session.transcriptSegments.count))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(session.status.displayName(language: language))
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(statusBackground, in: RoundedRectangle(cornerRadius: ReviewTraceStyle.badgeCornerRadius, style: .continuous))
                .foregroundStyle(statusForeground)
        }
        .padding(12)
        .reviewTraceCard()
    }

    private var statusBackground: Color {
        session.status == .ready ? ReviewTraceStyle.successColor.opacity(0.14) : Color.orange.opacity(0.14)
    }

    private var statusForeground: Color {
        session.status == .ready ? .green : .orange
    }

    private var iconColors: [Color] {
        switch session.resolvedSourceKind {
        case .screenRecording:
            return [ReviewTraceStyle.accentColor.opacity(0.9), .purple.opacity(0.8)]
        case .audioFile:
            return [.teal.opacity(0.85), ReviewTraceStyle.accentColor.opacity(0.78)]
        }
    }
}

private struct InstructionLine: View {
    var number: Int
    var text: String

    var body: some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.caption.bold().monospacedDigit())
                .frame(width: 22, height: 22)
                .background(ReviewTraceStyle.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: ReviewTraceStyle.badgeCornerRadius, style: .continuous))
                .foregroundStyle(ReviewTraceStyle.accentColor)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environment(ReviewTraceStore())
    }
}
