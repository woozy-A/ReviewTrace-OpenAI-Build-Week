import AVKit
import SwiftUI
import UIKit

private enum ReviewDetailTab: String, CaseIterable, Identifiable {
    case timeline = "Timeline"
    case codex = "Codex"
    case export = "Export"

    var id: String { rawValue }

    func title(copy: AppCopy) -> String {
        switch self {
        case .timeline: copy.timeline
        case .codex: copy.codex
        case .export: copy.export
        }
    }
}

struct ReviewDetailView: View {
    @Environment(ReviewTraceStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let sessionID: UUID

    @State private var selectedTab: ReviewDetailTab = .timeline
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var copiedPrompt = false
    @State private var deleteAlert: ReviewDetailDeleteAlert?
    @State private var showsTitleEditor = false
    @State private var draftTitle = ""

    var body: some View {
        let copy = store.copy

        Group {
            if let session = store.session(with: sessionID) {
                detail(for: session, copy: copy)
            } else {
                ContentUnavailableView(
                    copy.reviewNotFound,
                    systemImage: "doc.text.magnifyingglass",
                    description: Text(copy.reviewNotFoundDescription)
                )
            }
        }
        .navigationTitle(copy.reviewNavigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if store.session(with: sessionID) != nil {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        if let session = store.session(with: sessionID) {
                            draftTitle = copy.displayTitle(session.title)
                            showsTitleEditor = true
                        }
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .accessibilityLabel(copy.editReviewTitle)

                    Button(role: .destructive) {
                        deleteAlert = .confirmDelete
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel(copy.deleteReview)
                }
            }
        }
        .sheet(isPresented: $showsTitleEditor) {
            EditReviewTitleSheet(title: $draftTitle, copy: copy) {
                store.updateSessionTitle(id: sessionID, title: draftTitle)
            }
            .presentationDetents([.height(240)])
        }
        .alert(item: $deleteAlert) { alert in
            switch alert {
            case .confirmDelete:
                Alert(
                    title: Text(copy.deleteReviewConfirmTitle),
                    message: Text(copy.deleteReviewConfirmMessage),
                    primaryButton: .destructive(Text(copy.delete)) {
                        let title = store.session(with: sessionID).map { copy.displayTitle($0.title) } ?? copy.reviewNavigationTitle
                        if store.deleteSession(id: sessionID) {
                            DispatchQueue.main.async {
                                deleteAlert = .deleteCompleted(title)
                            }
                        }
                    },
                    secondaryButton: .cancel(Text(copy.cancel))
                )
            case .deleteCompleted(let title):
                Alert(
                    title: Text(copy.deleteCompletedTitle),
                    message: Text(copy.deleteReviewCompletedMessage(title)),
                    dismissButton: .default(Text(copy.ok)) {
                        dismiss()
                    }
                )
            }
        }
    }

    private func detail(for session: ReviewSession, copy: AppCopy) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                titleBlock(session, copy: copy)
                mediaPreview(session, copy: copy)
                tabPicker(copy: copy)
                tabContent(session, copy: copy)
            }
            .padding()
            .padding(.bottom, 40)
        }
        .background(ReviewTraceStyle.screenBackground.ignoresSafeArea())
        .onAppear {
            configurePlayerIfNeeded(for: session)
        }
    }

    private func titleBlock(_ session: ReviewSession, copy: AppCopy) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(copy.displayTitle(session.title))
                .font(.system(size: 30, weight: .bold))
            HStack(spacing: 8) {
                MetadataPill(systemImage: "clock", text: ReviewTimeFormatter.clock(session.duration))
                MetadataPill(systemImage: "text.bubble", text: copy.transcriptCount(session.transcriptSegments.count))
                MetadataPill(systemImage: session.resolvedSourceKind == .audioFile ? "waveform" : "play.rectangle", text: copy.sourceLabel(for: session.resolvedSourceKind))
                StatusPill(text: session.status.displayName(language: store.appLanguage), status: session.status)
            }
        }
    }

    @ViewBuilder
    private func mediaPreview(_ session: ReviewSession, copy: AppCopy) -> some View {
        switch session.resolvedSourceKind {
        case .screenRecording:
            videoPreview(session, copy: copy)
        case .audioFile:
            audioPreview(session, copy: copy)
        }
    }

    private func videoPreview(_ session: ReviewSession, copy: AppCopy) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let player {
                VideoPlayer(player: player)
                    .frame(height: 172)
                    .clipShape(RoundedRectangle(cornerRadius: ReviewTraceStyle.panelCornerRadius, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        Label(copy.videoPreview, systemImage: "play.rectangle.fill")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.56), in: RoundedRectangle(cornerRadius: ReviewTraceStyle.badgeCornerRadius, style: .continuous))
                            .foregroundStyle(.white)
                            .padding(10)
                    }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "video.slash")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text(copy.videoUnavailable)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .reviewTraceCard()
            }
        }
    }

    private func audioPreview(_ session: ReviewSession, copy: AppCopy) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if player != nil {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(ReviewTraceStyle.accentColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(copy.audioPreview)
                            .font(.headline)
                        Text(session.micAudioURL?.lastPathComponent ?? copy.importedAudioReviewTitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text(ReviewTimeFormatter.clock(session.duration))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        togglePlayback()
                    } label: {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 42))
                    }
                    .accessibilityLabel(isPlaying ? "일시정지" : "재생")
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "waveform.slash")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text(copy.audioUnavailable)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .reviewTraceCard()
    }

    private func tabPicker(copy: AppCopy) -> some View {
        Picker(copy.reviewNavigationTitle, selection: $selectedTab) {
            ForEach(ReviewDetailTab.allCases) { tab in
                Text(tab.title(copy: copy)).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private func tabContent(_ session: ReviewSession, copy: AppCopy) -> some View {
        switch selectedTab {
        case .timeline:
            TimelineTabView(session: session, copy: copy) { timestamp in
                seek(to: timestamp)
            }
        case .codex:
            CodexTabView(session: session, copy: copy, copiedPrompt: $copiedPrompt)
        case .export:
            ExportTabView(session: session, copy: copy)
        }
    }

    private func configurePlayerIfNeeded(for session: ReviewSession) {
        guard player == nil, let url = session.primaryMediaURL else { return }
        player = AVPlayer(url: url)
    }

    private func seek(to seconds: TimeInterval) {
        guard let player else { return }
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
    }

    private func togglePlayback() {
        guard let player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
}

private enum ReviewDetailDeleteAlert: Identifiable {
    case confirmDelete
    case deleteCompleted(String)

    var id: String {
        switch self {
        case .confirmDelete: "confirmDelete"
        case .deleteCompleted(let title): "deleteCompleted-\(title)"
        }
    }
}

private struct MetadataPill: View {
    var systemImage: String
    var text: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(ReviewTraceStyle.cardBackground, in: RoundedRectangle(cornerRadius: ReviewTraceStyle.badgeCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ReviewTraceStyle.badgeCornerRadius, style: .continuous)
                    .stroke(ReviewTraceStyle.borderColor, lineWidth: 1)
            )
    }
}

private struct StatusPill: View {
    var text: String
    var status: ReviewSessionStatus

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: ReviewTraceStyle.badgeCornerRadius, style: .continuous))
            .foregroundStyle(foregroundColor)
    }

    private var backgroundColor: Color {
        switch status {
        case .ready:
            return ReviewTraceStyle.successColor.opacity(0.14)
        case .failed:
            return Color.red.opacity(0.12)
        case .processing:
            return ReviewTraceStyle.accentColor.opacity(0.12)
        default:
            return Color.orange.opacity(0.12)
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .ready:
            return .green
        case .failed:
            return .red
        case .processing:
            return ReviewTraceStyle.accentColor
        default:
            return .orange
        }
    }
}

private struct EditReviewTitleSheet: View {
    @Binding var title: String
    var copy: AppCopy
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(copy.reviewTitle, text: $title)
                        .textInputAutocapitalization(.words)
                } footer: {
                    Text(copy.reviewTitleHelp)
                }
            }
            .navigationTitle(copy.editReviewTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(copy.cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(copy.save) {
                        onSave()
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

private enum TimelineDisplayMode: String, CaseIterable, Identifiable {
    case readable
    case original

    var id: String { rawValue }

    func title(copy: AppCopy) -> String {
        switch self {
        case .readable: copy.readableTimeline
        case .original: copy.originalTimeline
        }
    }
}

private struct TimelineTabView: View {
    var session: ReviewSession
    var copy: AppCopy
    var onSeek: (TimeInterval) -> Void
    @State private var displayMode: TimelineDisplayMode = .readable

    var body: some View {
        let readableSegments = ReadableTimelineBuilder().build(from: session.transcriptSegments)
        let isReadableMode = displayMode == .readable && !readableSegments.isEmpty
        let displayedSegments = isReadableMode ? readableSegments : session.transcriptSegments
        let previewVideoURL = (
            isReadableMode && session.resolvedSourceKind == .screenRecording
        ) ? session.videoURL : nil

        VStack(alignment: .leading, spacing: 12) {
            if session.transcriptSegments.isEmpty {
                ContentUnavailableView(copy.noTimeline, systemImage: "text.bubble")
            } else {
                Text(copy.timeline)
                    .font(.headline)

                Picker(copy.timeline, selection: $displayMode) {
                    ForEach(TimelineDisplayMode.allCases) { mode in
                        Text(mode.title(copy: copy)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(displayMode == .readable ? copy.readableTimelineDescription : copy.originalTimelineDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)

                LazyVStack(spacing: 12) {
                    ForEach(displayedSegments) { segment in
                        TimelineRow(
                            segment: segment,
                            copy: copy,
                            sourceKind: session.resolvedSourceKind,
                            previewVideoURL: previewVideoURL
                        ) {
                            onSeek(segment.startTime)
                        }
                    }
                }
            }
        }
    }
}

private struct TimelineRow: View {
    var segment: TranscriptSegment
    var copy: AppCopy
    var sourceKind: ReviewSourceKind
    var previewVideoURL: URL?
    var onSeek: () -> Void

    var body: some View {
        Button(action: onSeek) {
            HStack(alignment: .top, spacing: 12) {
                if let previewVideoURL {
                    TimelineFramePreview(
                        videoURL: previewVideoURL,
                        timestamp: segment.startTime
                    )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(ReviewTimeFormatter.clock(segment.startTime))
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .foregroundStyle(ReviewTraceStyle.accentColor)
                    Text(ReviewTimeFormatter.clock(segment.endTime))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .frame(width: 62, alignment: .leading)

                Text(segment.text)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "play.circle.fill")
                    .font(.title3)
                    .foregroundStyle(ReviewTraceStyle.accentColor.opacity(0.78))
                    .accessibilityHidden(true)
            }
            .padding(14)
            .reviewTraceCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(ReviewTimeFormatter.clock(segment.startTime)), \(segment.text)")
        .accessibilityHint(copy.jumpToSource(for: sourceKind))
    }
}

private struct TimelineFramePreview: View {
    let videoURL: URL
    let timestamp: TimeInterval

    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var didFail = false

    private var taskID: String {
        let scaledTimestamp = max(0, timestamp) * 10
        let timeKey: String
        if timestamp.isFinite,
           scaledTimestamp.isFinite,
           scaledTimestamp <= Double(Int.max) {
            timeKey = String(Int(scaledTimestamp.rounded()))
        } else {
            timeKey = "invalid"
        }
        return "\(videoURL.standardizedFileURL.path)#\(timeKey)"
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.secondary.opacity(0.10))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: didFail ? "photo.badge.exclamationmark" : "photo")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 84, height: 128)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityHidden(true)
        .task(id: taskID) {
            image = nil
            isLoading = true
            didFail = false

            do {
                image = try await TimelineFrameProvider().frame(
                    from: videoURL,
                    at: timestamp
                )
            } catch is CancellationError {
                return
            } catch {
                didFail = true
            }

            isLoading = false
        }
    }
}

private struct CodexTabView: View {
    var session: ReviewSession
    var copy: AppCopy
    @Binding var copiedPrompt: Bool
    @State private var showsFullPrompt = false

    var body: some View {
        let prompt = CodexPromptService().generate(for: session, language: copy.language)
        let sourceKind = session.resolvedSourceKind

        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 14) {
                Label(copy.codexPromptTitle, systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(ReviewTraceStyle.accentColor)

                Text(copy.codexPromptSummary(for: sourceKind))
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineSpacing(3)

                VStack(alignment: .leading, spacing: 8) {
                    Text(copy.includedContents)
                        .font(.subheadline.weight(.semibold))
                    IncludedContentLine(text: sourceKind == .audioFile ? copy.includedAudio : copy.includedVideo)
                    IncludedContentLine(text: copy.includedTimeline)
                    IncludedContentLine(text: copy.includedPrompt)
                }
            }
            .padding(16)
            .reviewTraceCard()

            Button {
                UIPasteboard.general.string = prompt
                copiedPrompt = true
            } label: {
                Label(copiedPrompt ? copy.copied : copy.copyCodexPrompt, systemImage: copiedPrompt ? "checkmark" : "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ReviewTracePrimaryButtonStyle())

            DisclosureGroup(copy.fullPrompt, isExpanded: $showsFullPrompt) {
                Text(prompt)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.subheadline.weight(.semibold))
            .padding(14)
            .reviewTraceCard()
        }
    }
}

private struct ExportTabView: View {
    @Environment(ReviewTraceStore.self) private var store
    var session: ReviewSession
    var copy: AppCopy

    var body: some View {
        let sourceKind = session.resolvedSourceKind
        let requiresOptimizedVideo = store.requiresOptimizedVideoForCodexPackage(sessionID: session.id)
        let compressionSnapshot = store.videoCompressionSnapshot?.sessionID == session.id
            ? store.videoCompressionSnapshot
            : nil
        let packageIsReady = !requiresOptimizedVideo && compressionSnapshot?.isActive != true
        let codexPackageItems = session.codexPackageMediaURLs + [
            session.codexBriefURL,
            session.markdownURL
        ].compactMap { $0 }

        VStack(alignment: .leading, spacing: 18) {
            if !codexPackageItems.isEmpty {
                Text(copy.recommendedExport)
                    .font(.headline)

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "shippingbox.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(ReviewTraceStyle.accentColor, in: RoundedRectangle(cornerRadius: ReviewTraceStyle.controlCornerRadius, style: .continuous))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(copy.shareOptionsTitle)
                                .font(.headline)
                            Text(copy.codexPackageSummary(for: sourceKind))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineSpacing(2)
                        }
                    }

                    if sourceKind == .screenRecording {
                        optimizedVideoControl
                    }

                    if packageIsReady {
                        ShareLink(items: codexPackageItems) {
                            Label(copy.shareVideoAndReview, systemImage: "paperplane")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ReviewTracePrimaryButtonStyle())
                    } else if requiresOptimizedVideo {
                        Label(copy.optimizedVideoRequired, systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let chatGPTReviewURL = session.chatGPTReviewURL {
                        ShareLink(item: chatGPTReviewURL) {
                            Label(copy.shareToChatGPT, systemImage: "doc.text")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ReviewTraceSecondaryButtonStyle())
                    }

                    if packageIsReady {
                        MediaOnlyShareLink(
                            urls: session.codexPackageMediaURLs,
                            label: copy.shareMediaOnly(
                                for: sourceKind,
                                partCount: session.codexPackageMediaURLs.count
                            )
                        )
                    }
                }
                .padding(16)
                .reviewTraceCard()
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(copy.otherExportFormats)
                    .font(.headline)

                VStack(spacing: 8) {
                    ExportOptionRow(
                        title: copy.language == .korean ? "읽기용 타임라인 (.md)" : "Readable Timeline (.md)",
                        description: copy.exportReadableTimelineDescription,
                        systemImage: "text.alignleft",
                        color: .indigo,
                        url: session.readableTimelineURL
                    )
                    ExportOptionRow(
                        title: copy.language == .korean ? "원문 타임라인 (.md)" : "Original Timeline (.md)",
                        description: copy.exportOriginalTimelineDescription,
                        systemImage: "text.badge.checkmark",
                        color: .green,
                        url: session.originalTimelineURL
                    )
                    ExportOptionRow(
                        title: copy.language == .korean ? "JSON (.json)" : "JSON (.json)",
                        description: copy.exportJSONDescription,
                        systemImage: "curlybraces",
                        color: .orange,
                        url: session.jsonURL
                    )
                    ExportOptionRow(
                        title: "SRT \((copy.language == .korean) ? "자막" : "Subtitles") (.srt)",
                        description: copy.exportSRTDescription,
                        systemImage: "captions.bubble",
                        color: .purple,
                        url: session.srtURL
                    )
                    ExportOptionRow(
                        title: "VTT \((copy.language == .korean) ? "웹 자막" : "Web Subtitles") (.vtt)",
                        description: copy.exportVTTDescription,
                        systemImage: "captions.bubble.fill",
                        color: .blue,
                        url: session.vttURL
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var optimizedVideoControl: some View {
        let optimizedParts = session.resolvedOptimizedVideoParts
        let snapshot = store.videoCompressionSnapshot?.sessionID == session.id
            ? store.videoCompressionSnapshot
            : nil
        let requiresOptimizedVideo = store.requiresOptimizedVideoForCodexPackage(sessionID: session.id)

        if let snapshot, snapshot.isActive {
            VStack(alignment: .leading, spacing: 8) {
                Text(copy.videoCompressionTitle(snapshot))
                    .font(.footnote.weight(.semibold))
                ProgressView(value: snapshot.progress)
                if let detail = copy.videoCompressionDetail(snapshot) {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button {
                    store.cancelVideoCompression(sessionID: session.id)
                } label: {
                    Label(copy.cancelVideoCompression, systemImage: "stop.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ReviewTraceSecondaryButtonStyle())
            }
        } else if let snapshot, snapshot.stage == .failed || snapshot.stage == .cancelled {
            VStack(alignment: .leading, spacing: 8) {
                Text(copy.videoCompressionTitle(snapshot))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(snapshot.stage == .failed ? .red : .secondary)
                if let error = snapshot.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Button {
                    optimizeVideo()
                } label: {
                    Label(copy.retryVideoCompression, systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ReviewTraceSecondaryButtonStyle())
            }
        } else if requiresOptimizedVideo {
            VStack(alignment: .leading, spacing: 8) {
                Text(copy.optimizedVideoDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)

                Button {
                    optimizeVideo()
                } label: {
                    Label(copy.makeOptimizedVideo, systemImage: "arrow.down.right.and.arrow.up.left")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ReviewTraceSecondaryButtonStyle())
            }
        } else if session.hasCurrentOptimizedVideoParts {
            VStack(alignment: .leading, spacing: 6) {
                Label(copy.optimizedVideoReady(partCount: optimizedParts.count), systemImage: "checkmark.circle.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.green)

                ForEach(optimizedParts) { part in
                    Text("\(ReviewTimeFormatter.clock(part.startTime))–\(ReviewTimeFormatter.clock(part.startTime + part.duration)) · \(ByteCountFormatter.string(fromByteCount: part.fileSize, countStyle: .file))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func optimizeVideo() {
        Task {
            await store.prepareOptimizedVideoForCodexPackage(sessionID: session.id)
        }
    }
}

private struct MediaOnlyShareLink: View {
    var urls: [URL]
    var label: String

    @ViewBuilder
    var body: some View {
        if let url = urls.first, urls.count == 1 {
            ShareLink(item: url) {
                Label(label, systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ReviewTraceSecondaryButtonStyle())
        } else if !urls.isEmpty {
            ShareLink(items: urls) {
                Label(label, systemImage: "square.and.arrow.up.on.square")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ReviewTraceSecondaryButtonStyle())
        }
    }
}

private struct IncludedContentLine: View {
    var text: String

    var body: some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .symbolRenderingMode(.hierarchical)
    }
}

private struct ExportOptionRow: View {
    var title: String
    var description: String
    var systemImage: String
    var color: Color
    var url: URL?

    var body: some View {
        if let url {
            ShareLink(item: url) {
                ExportOptionLabel(title: title, description: description, systemImage: systemImage, color: color)
            }
        } else {
            ExportOptionLabel(title: title, description: description, systemImage: systemImage, color: color)
                .opacity(0.45)
        }
    }
}

private struct ExportOptionLabel: View {
    var title: String
    var description: String
    var systemImage: String
    var color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(color, in: RoundedRectangle(cornerRadius: ReviewTraceStyle.badgeCornerRadius))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .reviewTraceCard()
    }
}

#Preview {
    NavigationStack {
        ReviewDetailView(sessionID: ReviewFixtures.sampleSession().id)
            .environment(ReviewTraceStore())
    }
}
