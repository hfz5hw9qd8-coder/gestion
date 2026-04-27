import Foundation
import SwiftUI

struct Helpers {
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    static func getColor(_ colorName: String) -> Color {
        switch colorName {
        case "red":
            return .red
        case "green":
            return .green
        case "blue":
            return .blue
        case "orange":
            return .orange
        case "yellow":
            return .yellow
        case "purple":
            return .purple
        case "pink":
            return .pink
        default:
            return .blue
        }
    }
    
    static func isOverdue(_ date: Date) -> Bool {
        return Calendar.current.isDateInPast(date, granularity: .day)
    }
}

extension Calendar {
    func isDateInPast(_ date: Date, granularity: Calendar.Component) -> Bool {
        guard let now = Calendar.current.startOfDay(for: Date()) as Date?,
              let checkDate = Calendar.current.startOfDay(for: date) as Date? else {
            return false
        }
        return checkDate < now
    }
}
