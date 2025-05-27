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

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
        let now = Date.now
        let timeDifference = abs(now.timeIntervalSince(self))
        
        // Return "now" if < 1 min
        if timeDifference < 60 {
            return "now"
        }
        
        let rDF = RelativeDateTimeFormatter()
        rDF.unitsStyle = .abbreviated
        return rDF.localizedString(for: self, relativeTo: now)
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

/// Combine a List & ForEach into a single struct
/// - Source: https://www.swiftbysundell.com/articles/building-editable-swiftui-lists/
struct EditableList<
    Data: RandomAccessCollection & MutableCollection & RangeReplaceableCollection,
    Content: View
>: View where Data.Element: Identifiable {
    @Binding var data: Data
    var content: (Binding<Data.Element>) -> Content

    init(_ data: Binding<Data>,
         content: @escaping (Binding<Data.Element>) -> Content)
    {
        self._data = data
        self.content = content
    }

    var body: some View {
        List {
            ForEach($data, content: content)
                .onMove { indexSet, offset in
                    data.move(fromOffsets: indexSet, toOffset: offset)
                }
                .onDelete { indexSet in
                    data.remove(atOffsets: indexSet)
                }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
        }
    }
}

/// Extract error code from localizedDescription with some goofy regex
func extractShazamErrorCode(from text: String) -> String {
    guard let range = text.range(of: "com.apple.ShazamKit error \\d+", options: .regularExpression),
          let codeRange = text[range].range(of: "\\d+$", options: .regularExpression) else {
        return ""
    }
    return String(text[codeRange])
}
