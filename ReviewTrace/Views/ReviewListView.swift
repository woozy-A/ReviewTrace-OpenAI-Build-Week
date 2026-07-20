import SwiftUI

struct ReviewListView: View {
    @Environment(ReviewTraceStore.self) private var store
    @State private var deleteAlert: ReviewListDeleteAlert?

    var body: some View {
        let copy = store.copy

        List {
            if store.sessions.isEmpty {
                ContentUnavailableView(
                    copy.noReviewsTitle,
                    systemImage: "doc.text.magnifyingglass",
                    description: Text(copy.noReviewsDescription)
                )
            } else {
                ForEach(store.sessions) { session in
                    NavigationLink(value: AppRoute.reviewDetail(session.id)) {
                        ReviewRow(session: session, language: store.appLanguage)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            deleteAlert = .confirmDelete(session)
                        } label: {
                            Label(copy.delete, systemImage: "trash")
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(copy.reviewsTab)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: AppRoute.importVideo) {
                    Image(systemName: "video.badge.plus")
                }
                .accessibilityLabel(copy.importExistingRecording)
            }
        }
        .alert(item: $deleteAlert) { alert in
            switch alert {
            case .confirmDelete(let session):
                Alert(
                    title: Text(copy.deleteReviewConfirmTitle),
                    message: Text(copy.deleteReviewConfirmMessage),
                    primaryButton: .destructive(Text(copy.delete)) {
                        let title = copy.displayTitle(session.title)
                        if store.deleteSession(id: session.id) {
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
                    dismissButton: .default(Text(copy.ok))
                )
            }
        }
    }
}

private enum ReviewListDeleteAlert: Identifiable {
    case confirmDelete(ReviewSession)
    case deleteCompleted(String)

    var id: String {
        switch self {
        case .confirmDelete(let session): "confirmDelete-\(session.id.uuidString)"
        case .deleteCompleted(let title): "deleteCompleted-\(title)"
        }
    }
}
