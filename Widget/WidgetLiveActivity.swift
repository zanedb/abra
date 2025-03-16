//
//  WidgetLiveActivity.swift
//  Widget
//

import ActivityKit
import WidgetKit
import SwiftUI

struct WidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WidgetAttributes.self) { context in
            HStack {
                leading
                    .foregroundStyle(.white)
                center(context: context)
                    .foregroundStyle(.white)
                trailing(context: context)
            }
                .activityBackgroundTint(.black)
                .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    leading
                }
                DynamicIslandExpandedRegion(.trailing) {
                    trailing(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    center(context: context)
                }
            } compactLeading: {
                Image(systemName: "shazam.logo.fill")
            } compactTrailing: {
                Image(systemName: "waveform")
            } minimal: {
                Image(systemName: "shazam.logo.fill")
            }
        }
    }
    
    var leading: some View{
        Image(systemName: "shazam.logo.fill")
            .resizable()
            .frame(width: 55, height: 55)
    }
    
    func trailing(context: ActivityViewContext<WidgetAttributes>) -> some View {
        Button(intent: DismissLiveActivityIntent(activityID: context.activityID)) {
            Image(systemName: "xmark.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .resizable()
                .font(Font.title.weight(.light))
                .foregroundStyle(.blue)
                .frame(width: 55, height: 55)
                .accessibilityLabel("Stop listening")
        }
            .buttonStyle(PlainButtonStyle())
    }
    
    func center(context: ActivityViewContext<WidgetAttributes>) -> some View {
        HStack(spacing: 0) {
            Text(context.state.takingTooLong ? "Still listening…" : "Listening…")
                .font(.system(size: 17, weight: .bold))
                .padding(.leading, 5)
            
            Spacer()
        }
    }
}

struct WidgetLiveActivity_Previews: PreviewProvider {
    static let attributes = WidgetAttributes()
    
    static let contentState = WidgetAttributes.ContentState(takingTooLong: false)
    
    static var previews: some View {
        attributes
            .previewContext(contentState, viewKind: .dynamicIsland(.compact))
            .previewDisplayName("Island Compact")
        attributes
            .previewContext(contentState, viewKind: .dynamicIsland(.expanded))
            .previewDisplayName("Island Expanded")
        attributes
            .previewContext(contentState, viewKind: .dynamicIsland(.minimal))
            .previewDisplayName("Minimal")
        attributes
            .previewContext(contentState, viewKind: .content)
            .previewDisplayName("Notification")
    }
}
