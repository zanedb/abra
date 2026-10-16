import ActivityKit
import SwiftUI
import WidgetKit

struct LiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WidgetAttributes.self) { context in
            HStack(spacing: 14) {
                Image("abra.logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 42, height: 42)
                    .accessibilityHidden(true)

                status(context: context)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if context.state.matchedTitle == nil {
                    stopButton(activityID: context.activityID)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .foregroundStyle(.white)
            .activityBackgroundTint(.black)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image("abra.logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .accessibilityHidden(true)
                }
                DynamicIslandExpandedRegion(.center) {
                    status(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.matchedTitle == nil {
                        stopButton(activityID: context.activityID)
                    }
                }
            } compactLeading: {
                Image("abra.logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .accessibilityLabel("Abra")
            } compactTrailing: {
                Image(systemName: "waveform")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .accessibilityLabel(context.state.matchedTitle == nil ? "Listening" : "Matched")
            } minimal: {
                if context.state.matchedTitle != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityLabel("Matched")
                } else {
                    Image("abra.logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .accessibilityLabel("Listening")
                }
            }
        }
    }

    private func status(context: ActivityViewContext<WidgetAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title = context.state.matchedTitle {
                Label("Matched", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.green)
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                if let artist = context.state.matchedArtist {
                    Text(artist)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                }
            } else {
                HStack(spacing: 7) {
                    Waveform(on: true, size: 2, animated: false)
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                    Text(context.state.takingTooLong && !context.state.continuous
                         ? "Still listening…" : "Listening")
                        .font(.subheadline.bold())
                }

                if context.state.continuous {
                    Text(context.state.matchCount == 1
                         ? "1 song found"
                         : "\(context.state.matchCount) songs found")
                        .font(.headline)
                        .contentTransition(.numericText())

                    Label(
                        context.state.locationName ?? "Location unavailable",
                        systemImage: context.state.locationName == nil ? "location.slash" : "location.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func stopButton(activityID: String) -> some View {
        Button(intent: EndShazamSessionIntent(activityID: activityID)) {
            Image(systemName: "stop.fill")
                .font(.headline)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.14), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Stop listening")
    }
}

struct LiveActivity_Previews: PreviewProvider {
    static let attributes = WidgetAttributes()
    static let oneShot = WidgetAttributes.ContentState(takingTooLong: false)
    static let continuous = WidgetAttributes.ContentState(
        takingTooLong: false,
        continuous: true,
        matchCount: 3,
        locationName: "Mission District"
    )
    static let matched = WidgetAttributes.ContentState(
        takingTooLong: false,
        matchedTitle: "Midnight City",
        matchedArtist: "M83"
    )

    static var previews: some View {
        attributes.previewContext(oneShot, viewKind: .content)
            .previewDisplayName("One song")
        attributes.previewContext(continuous, viewKind: .content)
            .previewDisplayName("Continuous")
        attributes.previewContext(matched, viewKind: .content)
            .previewDisplayName("Matched")
        attributes.previewContext(continuous, viewKind: .dynamicIsland(.expanded))
            .previewDisplayName("Island Expanded")
        attributes.previewContext(continuous, viewKind: .dynamicIsland(.compact))
            .previewDisplayName("Island Compact")
        attributes.previewContext(continuous, viewKind: .dynamicIsland(.minimal))
            .previewDisplayName("Island Minimal")
    }
}
