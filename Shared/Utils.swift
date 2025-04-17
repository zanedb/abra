//
//  Utils.swift
//  Abra
//

import SwiftUI

// MARK: - View.fillFrame()
// https://github.com/sindresorhus/Blear/blob/5326e9b891e609c23641d43b966501afe21019ca/Blear/Utilities.swift#L1891
extension View {
    /**
     Fills the frame.
     */
    func fillFrame(
        _ axis: Axis.Set = [.horizontal, .vertical],
        alignment: Alignment = .center
    ) -> some View {
        frame(
            maxWidth: axis.contains(.horizontal) ? .infinity : nil,
            maxHeight: axis.contains(.vertical) ? .infinity : nil,
            alignment: alignment
        )
    }
}

// MARK: - VisualEffectView()
// Borrowing from UIKit...
struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?
    func makeUIView(context: UIViewRepresentableContext<Self>) -> UIVisualEffectView { UIVisualEffectView() }
    func updateUIView(_ uiView: UIVisualEffectView, context: UIViewRepresentableContext<Self>) { uiView.effect = effect }
}


// MARK: - Date Helpers
extension Date {
    var isInLastSevenDays: Bool {
        let now = Date()
        guard let aWeekAgo = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: now) else { return false }
        return self <= now && self > aWeekAgo
    }
    
    var isInLastThirtyDays: Bool {
        let now = Date()
        guard let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: now) else { return false }
        return self <= now && self > thirtyDaysAgo
    }
    
    var isThisYear: Bool {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year], from: self)
        let currentYearComponents = calendar.dateComponents([.year], from: Date())
        
        return dateComponents.year == currentYearComponents.year
    }
    
    var month: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM"
        return dateFormatter.string(from: self)
    }
    
    var year: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy"
        return dateFormatter.string(from: self)
    }
    
    var timeSince: String {
        let rDF = RelativeDateTimeFormatter()
        rDF.unitsStyle = .abbreviated
        return rDF.localizedString(for: self, relativeTo: Date.now)
    }
    
    var relativeGroupString: String {
        if Calendar.current.isDateInToday(self) {
            return "Today"
        } else if isInLastSevenDays {
            return "Last 7 Days"
        } else if isInLastThirtyDays {
            return "Last 30 Days"
        } else if isThisYear {
            return month
        } else {
            return "\(month) \(year)"
        }
    }
}
