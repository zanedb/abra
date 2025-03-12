//
//  widgetLiveActivity.swift
//  widget
//
//  Created by Zane on 3/10/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct widgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WidgetAttributes.self) { context in
            HStack {
                leading
                center
                trailing
            }
                .padding()
                .activityBackgroundTint(nil)
                .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    leading
                }
                DynamicIslandExpandedRegion(.trailing) {
                    trailing
                }
                DynamicIslandExpandedRegion(.center) {
                    center
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
            .frame(width: 59, height: 59)
    }
    
    var trailing: some View {
        Image(systemName: "xmark.circle.fill")
            .symbolRenderingMode(.hierarchical)
            .resizable()
            .font(Font.title.weight(.light))
            .foregroundStyle(.blue)
            .frame(width: 59, height: 59)
            .accessibilityLabel("Stop listening")
    }
    
    var center: some View {
        HStack(spacing: 0) {
            Text("Listening...")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.blue, Color.white]), startPoint: .leading, endPoint: .trailing))
                .padding(.leading, 8)
            
            Spacer()
            
            Image(systemName: "waveform")
                .resizable()
                .frame(width: 20, height: 20)
                .foregroundStyle(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.blue, Color.white]), startPoint: .leading, endPoint: .trailing))
                .padding(.trailing, 9)
        }
    }
}

struct widgetLiveActivity_Previews: PreviewProvider {
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
