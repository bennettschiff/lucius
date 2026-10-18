import SwiftUI

struct HistoryView: View {
    let store: ScanStore
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("LOCAL RECORD").eyebrow()
            Text("A little context for next time.").font(.system(size: 30, weight: .light))
            Text("Your last 40 scan and repair summaries. Stored on this Mac; never uploaded.").font(.system(size: 12)).foregroundStyle(Theme.dim)
            if let notice = store.persistenceNotice { Text(notice).foregroundStyle(Theme.amber).font(.system(size: 12)) }
            if store.incidents.isEmpty {
                ContentUnavailableView("No scans yet", systemImage: "clock.arrow.circlepath", description: Text("Run your first scan to start a local history."))
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(store.incidents) { incident in
                            HStack(alignment: .top, spacing: 16) {
                                Image(systemName: incident.title.contains("restart") ? "arrow.clockwise" : "viewfinder")
                                    .foregroundStyle(Theme.cyan).padding(.top, 2)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(incident.title).font(.system(size: 14, weight: .medium))
                                    Text(incident.detail).font(.system(size: 12)).foregroundStyle(Theme.dim).lineSpacing(3)
                                }
                                Spacer()
                                Text(incident.date.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.dim)
                            }.padding(20).frame(maxWidth: .infinity, alignment: .leading).panel()
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }.padding(38)
    }
}
