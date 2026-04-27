import Foundation

enum GestionFormatters {
    static let euro: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter
    }()

    static let mediumFrenchDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .medium
        return formatter
    }()

    static let shortFrenchDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .short
        return formatter
    }()
}

extension Double {
    var formattedEuro: String {
        GestionFormatters.euro.string(from: NSNumber(value: self)) ?? "\(self) €"
    }

    var cleanNumber: String {
        truncatingRemainder(dividingBy: 1) == 0 ? String(Int(self)) : String(format: "%.2f", self)
    }
}

extension Date {
    var gestionDayLabel: String {
        if Calendar.current.isDateInToday(self) { return "Aujourd'hui" }
        if Calendar.current.isDateInTomorrow(self) { return "Demain" }
        return formatted(.dateTime.day().month(.abbreviated).year())
    }

    var gestionShortDayLabel: String {
        if Calendar.current.isDateInToday(self) { return "Aujourd'hui" }
        if Calendar.current.isDateInTomorrow(self) { return "Demain" }
        return formatted(.dateTime.day().month(.abbreviated))
    }

    var gestionDateString: String {
        GestionFormatters.shortFrenchDateTime.string(from: self)
    }
}

extension String {
    var nsString: NSString { self as NSString }
}
