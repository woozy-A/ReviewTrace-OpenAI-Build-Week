import SwiftUI

enum ReviewTraceStyle {
    static let panelCornerRadius: CGFloat = 8
    static let controlCornerRadius: CGFloat = 8
    static let badgeCornerRadius: CGFloat = 5

    static let screenBackground = Color(red: 0.968, green: 0.968, blue: 0.982)
    static let cardBackground = Color.white
    static let borderColor = Color.black.opacity(0.08)
    static let accentColor = Color.indigo
    static let successColor = Color.green
}

struct ReviewTracePrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.vertical, 13)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: ReviewTraceStyle.controlCornerRadius, style: .continuous)
                    .fill(ReviewTraceStyle.accentColor.opacity(isEnabled ? (configuration.isPressed ? 0.84 : 1) : 0.45))
            )
    }
}

struct ReviewTraceSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .foregroundStyle(isEnabled ? ReviewTraceStyle.accentColor : Color.secondary)
            .background(
                RoundedRectangle(cornerRadius: ReviewTraceStyle.controlCornerRadius, style: .continuous)
                    .fill(ReviewTraceStyle.cardBackground.opacity(configuration.isPressed ? 0.72 : 1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: ReviewTraceStyle.controlCornerRadius, style: .continuous)
                    .stroke(ReviewTraceStyle.accentColor.opacity(isEnabled ? 0.22 : 0.08), lineWidth: 1)
            )
    }
}

extension View {
    func reviewTraceCard(cornerRadius: CGFloat = ReviewTraceStyle.panelCornerRadius) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(ReviewTraceStyle.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(ReviewTraceStyle.borderColor, lineWidth: 1)
        )
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case reviews
    case settings

    var id: String { rawValue }

    @ViewBuilder
    func label(copy: AppCopy) -> some View {
        switch self {
        case .home:
            Label(copy.homeTab, systemImage: "house")
        case .reviews:
            Label(copy.reviewsTab, systemImage: "list.bullet.rectangle")
        case .settings:
            Label(copy.settingsTab, systemImage: "gearshape")
        }
    }
}

enum AppRoute: Hashable {
    case importVideo
    case processing
    case reviewDetail(UUID)
}

struct AppView: View {
    @Environment(ReviewTraceStore.self) private var store
    @State private var selectedTab: AppTab = .home
    @State private var homePath: [AppRoute] = []
    @State private var reviewsPath: [AppRoute] = []
    @State private var settingsPath: [AppRoute] = []

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack(path: $homePath) {
                HomeView()
                    .withAppDestinations()
            }
            .tabItem { AppTab.home.label(copy: store.copy) }
            .tag(AppTab.home)

            NavigationStack(path: $reviewsPath) {
                ReviewListView()
                    .withAppDestinations()
            }
            .tabItem { AppTab.reviews.label(copy: store.copy) }
            .tag(AppTab.reviews)

            NavigationStack(path: $settingsPath) {
                SettingsView()
                    .withAppDestinations()
            }
            .tabItem { AppTab.settings.label(copy: store.copy) }
            .tag(AppTab.settings)
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 10) {
                if store.isProcessing || store.processingSnapshot?.stage == .failed {
                    ProcessingBanner(
                        title: store.processingTitle,
                        progress: store.processingProgress,
                        snapshot: store.processingSnapshot,
                        copy: store.copy,
                        onRetry: {
                            Task { await store.retryLastFailedProcessing() }
                        },
                        onDismiss: {
                            store.dismissProcessingFailure()
                        },
                        onSelectAgain: {
                            let sourceKind = store.processingSnapshot?.sourceKind
                            store.dismissProcessingFailure()
                            selectedTab = .home
                            homePath.removeAll()
                            if sourceKind != .audioFile {
                                homePath.append(.importVideo)
                            }
                        }
                    )
                }

                if let compressionSnapshot = store.videoCompressionSnapshot {
                    VideoCompressionBanner(
                        snapshot: compressionSnapshot,
                        copy: store.copy,
                        onCancel: {
                            store.cancelVideoCompression(sessionID: compressionSnapshot.sessionID)
                        },
                        onRetry: {
                            Task {
                                await store.retryVideoCompression(sessionID: compressionSnapshot.sessionID)
                            }
                        },
                        onDismiss: {
                            store.dismissVideoCompressionStatus()
                        }
                    )
                }
            }
            .padding()
            .animation(.snappy, value: store.videoCompressionSnapshot)
            .animation(.snappy, value: store.processingSnapshot)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .tint(.indigo)
        .background(ReviewTraceStyle.screenBackground)
        .animation(.snappy, value: store.isProcessing)
        .alert(
            store.copy.errorTitle,
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        store.errorMessage = nil
                    }
                }
            )
        ) {
            Button(store.copy.ok) {
                store.errorMessage = nil
            }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}

private extension View {
    func withAppDestinations() -> some View {
        navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .importVideo:
                ImportVideoView()
            case .processing:
                ProcessingView()
            case .reviewDetail(let id):
                ReviewDetailView(sessionID: id)
            }
        }
    }
}

private struct ProcessingBanner: View {
    var title: String
    var progress: Double
    var snapshot: ReviewProcessingSnapshot?
    var copy: AppCopy
    var onRetry: () -> Void
    var onDismiss: () -> Void
    var onSelectAgain: () -> Void

    private var isFailed: Bool {
        snapshot?.stage == .failed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if isFailed {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                } else {
                    ProgressView()
                }
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                if isFailed {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(copy.close)
                }
            }
            ProgressView(value: progress)

            if let snapshot {
                VStack(alignment: .leading, spacing: 4) {
                    if snapshot.videoDuration > 0 {
                        let sourceKind = snapshot.sourceKind ?? .screenRecording
                        let processingLabel = sourceKind == .audioFile
                            ? (copy.language == .korean ? "음성 처리 중" : "audio")
                            : (copy.language == .korean ? "영상 처리 중" : "video")
                        Text("\(ReviewTimeFormatter.clock(snapshot.videoDuration)) \(processingLabel)")
                    }
                    if let warning = copy.lengthWarning(for: snapshot.videoDuration) {
                        Text(warning)
                            .foregroundStyle(.orange)
                    }
                    if snapshot.chunkCount > 0 {
                        Text(copy.chunkProgress(snapshot))
                    }
                    if let audioDuration = snapshot.extractedAudioDuration {
                        Text("\(copy.extractedAudio): \(ReviewTimeFormatter.clock(audioDuration))")
                    }
                    if let lastError = snapshot.lastError, !lastError.isEmpty {
                        Text("\(copy.failureReason): \(lastError)")
                            .foregroundStyle(.red)
                    }
                    if let failedChunk = snapshot.failedChunkDisplayIndex {
                        Text("\(copy.failedChunk): \(failedChunk)")
                            .foregroundStyle(.red)
                    }
                    if isFailed {
                        Button(action: onRetry) {
                            Label(copy.retryFailedChunk, systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ReviewTraceSecondaryButtonStyle())
                        .padding(.top, 4)
                        Button(action: onSelectAgain) {
                            Label(copy.closeAndSelectAgain, systemImage: "video.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ReviewTraceSecondaryButtonStyle())
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: ReviewTraceStyle.panelCornerRadius, style: .continuous))
        .shadow(radius: 12, y: 4)
    }
}

private struct VideoCompressionBanner: View {
    var snapshot: VideoCompressionSnapshot
    var copy: AppCopy
    var onCancel: () -> Void
    var onRetry: () -> Void
    var onDismiss: () -> Void

    private var isFailed: Bool { snapshot.stage == .failed }
    private var isCompleted: Bool { snapshot.stage == .completed }
    private var isCancelled: Bool { snapshot.stage == .cancelled }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                statusIcon
                Text(copy.videoCompressionTitle(snapshot))
                    .font(.headline)
                Spacer()
                Text("\(Int(snapshot.progress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                if !snapshot.isActive {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(copy.close)
                }
            }

            ProgressView(value: snapshot.progress)

            if let detail = copy.videoCompressionDetail(snapshot) {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let error = snapshot.lastError, !error.isEmpty {
                Text("\(copy.failureReason): \(error)")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if snapshot.isActive {
                Button(action: onCancel) {
                    Label(copy.cancelVideoCompression, systemImage: "stop.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ReviewTraceSecondaryButtonStyle())
            } else if isFailed || isCancelled {
                Button(action: onRetry) {
                    Label(copy.retryVideoCompression, systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ReviewTraceSecondaryButtonStyle())
            } else if isCompleted {
                Text(copy.optimizedVideoDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: ReviewTraceStyle.panelCornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ReviewTraceStyle.panelCornerRadius, style: .continuous)
                .stroke(ReviewTraceStyle.borderColor, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch snapshot.stage {
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        case .cancelled:
            Image(systemName: "stop.circle.fill")
                .foregroundStyle(.secondary)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(ReviewTraceStyle.successColor)
        case .preparing, .compressing, .installing:
            ProgressView()
        }
    }
}
