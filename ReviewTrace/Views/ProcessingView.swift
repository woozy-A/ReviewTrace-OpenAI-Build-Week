import SwiftUI

struct ProcessingView: View {
    @Environment(ReviewTraceStore.self) private var store

    var body: some View {
        let copy = store.copy
        let snapshot = store.processingSnapshot

        VStack(alignment: .leading, spacing: 24) {
            ProcessingTitleHeader(
                title: copy.processingTitle(for: snapshot ?? ReviewProcessingSnapshot(sessionID: UUID(), stage: .importingVideo)),
                snapshot: snapshot,
                copy: copy
            )

            ProgressView(value: snapshot?.progress ?? store.processingProgress) {
                Text("\(copy.progress): \(Int((snapshot?.progress ?? store.processingProgress) * 100))%")
            }

            if let snapshot {
                ProcessingSnapshotDetails(snapshot: snapshot, copy: copy) {
                    Task { await store.retryLastFailedProcessing() }
                }
            } else {
                ContentUnavailableView(copy.processingTitle, systemImage: "waveform")
            }

            Spacer()
        }
        .padding()
        .background(ReviewTraceStyle.screenBackground.ignoresSafeArea())
        .navigationTitle(copy.processingTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ProcessingTitleHeader: View {
    var title: String
    var snapshot: ReviewProcessingSnapshot?
    var copy: AppCopy

    private var stage: ReviewProcessingStage? {
        snapshot?.stage
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.largeTitle.bold())
                if let description {
                    Text(description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var systemImage: String {
        switch stage {
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        case nil:
            return "waveform"
        default:
            return "waveform.circle"
        }
    }

    private var color: Color {
        switch stage {
        case .completed:
            return .green
        case .failed:
            return .red
        default:
            return .indigo
        }
    }

    private var description: String? {
        switch stage {
        case .completed:
            return copy.processingCompletedDescription
        case .failed:
            return copy.processingFailedDescription
        default:
            return nil
        }
    }
}

private struct ProcessingSnapshotDetails: View {
    var snapshot: ReviewProcessingSnapshot
    var copy: AppCopy
    var onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProcessingInfoRow(title: copy.sourceLength(for: snapshot.sourceKind ?? .screenRecording), value: ReviewTimeFormatter.clock(snapshot.videoDuration))

            if let warning = copy.lengthWarning(for: snapshot.videoDuration) {
                Text(warning)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            if let audioDuration = snapshot.extractedAudioDuration {
                ProcessingInfoRow(title: copy.extractedAudio, value: ReviewTimeFormatter.clock(audioDuration))
            }

            ProcessingInfoRow(title: copy.totalChunks, value: "\(snapshot.chunkCount)")
            ProcessingInfoRow(title: copy.completedChunks, value: "\(snapshot.completedChunkCount)")

            if let currentChunk = snapshot.currentChunkDisplayIndex {
                ProcessingInfoRow(title: copy.currentChunk, value: "\(currentChunk)")
            }

            if snapshot.rawSegmentCount > 0 {
                ProcessingInfoRow(title: copy.rawSegments, value: "\(snapshot.rawSegmentCount)")
            }

            if snapshot.groupedTimelineRowCount > 0 {
                ProcessingInfoRow(title: copy.timelineRows, value: "\(snapshot.groupedTimelineRowCount)")
            }

            if let failedChunk = snapshot.failedChunkDisplayIndex {
                Divider()
                Text(copy.processingFailedDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("\(copy.failedChunk): \(failedChunk)")
                    .font(.headline)
                    .foregroundStyle(.red)
                if let lastError = snapshot.lastError {
                    Text(lastError)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Button(action: onRetry) {
                    Label(copy.retryFailedChunk, systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ReviewTraceSecondaryButtonStyle())
            }

            if snapshot.stage == .completed {
                Divider()
                Text(copy.processingCompletedDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .reviewTraceCard()
    }
}

private struct ProcessingInfoRow: View {
    var title: String
    var value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.body.monospacedDigit())
        }
    }
}
