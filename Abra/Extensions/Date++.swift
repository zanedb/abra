//
//  Date++.swift
//  Abra
//
//  Created by Zane Davis-Barrs on 12/14/25.
//

// MARK: - Date Helpers

import Foundation

public extension Date {
    /// Returns a title-cased string describing the day and a loose time bucket.
    /// Examples:
    /// - 11:59pm -> "Late Saturday"
    /// - 7:30pm  -> "Tuesday Afternoon"
    /// - 4:00am  -> "Early Monday"
    /// - 12:00pm -> "Midday Tuesday"
    ///
    /// Buckets:
    /// - Midnight:       12:00am exactly  -> "Midnight <Weekday>"
    /// - Early:          12:01am–4:59am   -> "Early <Weekday>"
    /// - Morning:        5:00am–11:59am   -> "<Weekday> Morning"
    /// - Midday:         12:00pm exactly  -> "Midday <Weekday>"
    /// - Afternoon:      12:01pm–4:59pm   -> "<Weekday> Afternoon"
    /// - Evening:        5:00pm–8:59pm    -> "<Weekday> Evening"
    /// - Late:           9:00pm–11:59pm   -> "Late <Weekday>"
    ///
    /// Titlecase ensured for both parts.
    func looseDescription(in timeZone: TimeZone = .current, locale: Locale = .current) -> String {
        // Calendar configured for the provided timezone/locale
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = locale

        // Extract hour/minute and weekday name
        let comps = calendar.dateComponents([.hour, .minute, .weekday], from: self)
        let hour = comps.hour ?? 0
        let minute = comps.minute ?? 0

        // Weekday name (e.g., "Monday")
        let weekday = self.formatted(.dateTime.weekday(.wide))

        // Decide bucket based on 24-hour time; treat exact noon/midnight specially
        let descriptor: String
        if hour == 0 && minute == 0 {
            descriptor = "Midnight \(weekday)"
        } else if hour == 12 && minute == 0 {
            descriptor = "Midday \(weekday)"
        } else {
            // General buckets
            switch (hour, minute) {
            case (0, 1...59), (1...4, _):
                descriptor = "Early \(weekday)"                  // 12:01am–4:59am
            case (5...11, _):
                descriptor = "\(weekday) Morning"                // 5:00am–11:59am
            case (12, 1...59), (13...16, _):
                descriptor = "\(weekday) Afternoon"              // 12:01pm–4:59pm
            case (17...20, _):
                descriptor = "\(weekday) Evening"                // 5:00pm–8:59pm
            case (21...23, _):
                descriptor = "Late \(weekday)"                   // 9:00pm–11:59pm
            default:
                // Fallback (shouldn't hit with valid hour/minute)
                descriptor = "\(weekday)"
            }
        }

        // Ensure Title Case (weekday already title-cased by "EEEE"; prefixes are Title Case literals)
        return descriptor
    }
    
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

    var day: String {
        self.formatted(.dateTime.month().day())
    }

    var month: String {
        self.formatted(.dateTime.month())
    }

    var year: String {
        self.formatted(.dateTime.year())
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
            return self.formatted(.dateTime.month(.wide))
        } else {
            return self.formatted(.dateTime.month(.wide).year())
        }
    }
}
