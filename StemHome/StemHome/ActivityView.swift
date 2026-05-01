import SwiftUI

struct ActivityView: View {

    let entries: [ActivityEntry]

    var body: some View {
        Group {
            if entries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No activity yet")
                        .font(.headline)
                    Text("Toggle a device on the Home tab — its event will appear here.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // TimelineView forces a periodic re-render so the relative
                // time labels tick without any manual Timer wiring.
                TimelineView(.periodic(from: .now, by: 5)) { timeline in
                    List {
                        ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.accentColor)
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(entry.deviceName) turned \(entry.action)")
                                        .font(.subheadline)
                                    Text(relativeTime(from: entry.timestamp, reference: timeline.date))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .navigationTitle("Activity")
    }

    private func relativeTime(from unix: Double, reference: Date) -> String {
        guard unix > 0 else { return "just now" }
        let date = Date(timeIntervalSince1970: unix)
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: reference)
    }
}
