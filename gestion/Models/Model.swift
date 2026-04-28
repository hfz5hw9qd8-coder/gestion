//
//  Model.swift
//  gestion
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - UI MODELS

struct DashboardMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let detail: String
    let icon: String
    let color: Color
}

struct DashboardHighlight: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let icon: String
    let color: Color
}

// MARK: - CLIENT

@Model
final class Client {
    var name: String
    var city: String
    var address: String
    var phone: String
    var email: String
    var note: String
    var status: String
    var outstandingBalance: Double
   

    @Relationship(deleteRule: .cascade)
    var quotes: [Quote] = []

    @Relationship(deleteRule: .cascade)
    var interventions: [Intervention] = []

    init(name: String,
         city: String,
         address: String,
         phone: String,
         email: String,
         note: String = "",
         status: String = "active") {

        self.name = name
        self.city = city
        self.address = address
        self.phone = phone
        self.email = email
        self.note = note
        self.status = status
    }
}

// MARK: - INTERVENTION

@Model
final class Intervention {
    var clientName: String
    var location: String
    var date: Date
    var timeSlot: String

    var priority: String
    var status: String
    var notes: String

    var sortDate: Date
    var kind: String

    @Relationship(deleteRule: .cascade)
    var stockUsages: [StockUsage] = []

    @Relationship
    var client: Client?

    init(clientName: String,
         location: String,
         date: Date,
         timeSlot: String,
         priority: String,
         status: String,
         notes: String = "") {

        self.clientName = clientName
        self.location = location
        self.date = date
        self.timeSlot = timeSlot
        self.priority = priority
        self.status = status
        self.notes = notes
        self.sortDate = date
    }
}

// MARK: - QUOTE

@Model
final class Quote {
    var reference: String
    var clientName: String
    var status: String
    var dueDate: Date
    var summary: String
    var depositRate: Double
    var documentType: String
    var label: String

    @Relationship(deleteRule: .cascade)
    var lines: [QuoteLine] = []

    @Relationship(deleteRule: .cascade)
    var payments: [Payment] = []

    @Relationship
    var client: Client?

    init(reference: String,
         clientName: String,
         status: String,
         dueDate: Date,
         summary: String,
         depositRate: Double = 30,
         documentType: String) {

        self.reference = reference
        self.clientName = clientName
        self.status = status
        self.dueDate = dueDate
        self.summary = summary
        self.depositRate = depositRate
        self.documentType = documentType
    }
}

// MARK: - QUOTE LINE

@Model
final class QuoteLine: Identifiable {
    var id: UUID = UUID()
    var title: String
    var lineDescription: String
    var quantity: Double
    var unitPrice: Double
    var taxRate: Double

    init(title: String,
         lineDescription: String,
         quantity: Double,
         unitPrice: Double,
         taxRate: Double) {

        self.title = title
        self.lineDescription = lineDescription
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.taxRate = taxRate
    }
}

// MARK: - PAYMENT

@Model
final class Payment {
    var amount: Double
    var paidAt: Date
    var method: String
    var note: String

    init(amount: Double,
         paidAt: Date,
         method: String,
         note: String = "") {

        self.amount = amount
        self.paidAt = paidAt
        self.method = method
        self.note = note
    }
}

// MARK: - INVENTORY

@Model
final class InventoryItem {
    var name: String
    var sku: String
    var quantity: Int
    var minimumQuantity: Int
    var unitCost: Double
    var supplier: String
    var location: String
    var stockLevel: String

    @Relationship(deleteRule: .cascade)
    var usages: [StockUsage] = []

    @Relationship(deleteRule: .cascade)
    var movements: [InventoryMovement] = []

    init(name: String,
         sku: String,
         quantity: Int,
         minimumQuantity: Int,
         unitCost: Double,
         supplier: String,
         location: String) {

        self.name = name
        self.sku = sku
        self.quantity = quantity
        self.minimumQuantity = minimumQuantity
        self.unitCost = unitCost
        self.supplier = supplier
        self.location = location
        self.stockLevel = "normal"
    }
}

// MARK: - STOCK USAGE

@Model
final class StockUsage {
    var inventoryItemName: String
    var quantityUsed: Int

    init(inventoryItemName: String,
         quantityUsed: Int) {

        self.inventoryItemName = inventoryItemName
        self.quantityUsed = quantityUsed
    }
}

// MARK: - MOVEMENT

@Model
final class InventoryMovement {
    var itemName: String
    var quantity: Int
    var date: Date
    var type: String

    init(itemName: String,
         quantity: Int,
         date: Date,
         type: String) {

        self.itemName = itemName
        self.quantity = quantity
        self.date = date
        self.type = type
    }
}

// MARK: - ENUMS
enum PriorityLevel: String, CaseIterable {
    case urgent
    case normal
    case quote

    var color: Color {
        switch self {
        case .urgent: return .red
        case .normal: return .blue
        case .quote: return .orange
        }
    }

    var label: String {
        switch self {
        case .urgent: return "Urgent"
        case .normal: return "Normal"
        case .quote: return "Devis"
        }
    }
}


enum InterventionStatus: String, CaseIterable {
    case planned
    case inProgress
    case completed
}

enum QuoteDocumentType: String, CaseIterable {
    case quote
    case invoice

    var label: String {
        switch self {
        case .quote: return "Devis"
        case .invoice: return "Facture"
        }
    }

    var color: Color {
        switch self {
        case .quote: return .blue
        case .invoice: return .purple
        }
    }
}

enum ClientStatus: String, CaseIterable {
    case active
    case priority
    case quote
}



enum QuoteStatus: String, CaseIterable {
    case pending
    case sent
    case late
    case paid

    var label: String {
        switch self {
        case .pending: return "En attente"
        case .sent: return "Envoyé"
        case .late: return "En retard"
        case .paid: return "Payé"
        }
    }
}



enum StockLevel: String, CaseIterable {
    case normal
    case warning
    case critical
}

// MARK: - EXTENSIONS (ERP LOGIC)

extension Client {
    var statusValue: ClientStatus {
        ClientStatus(rawValue: status) ?? .active
    }
}

extension ClientStatus {
    var color: Color {
        switch self {
        case .active: return .blue
        case .priority: return .green
        case .quote: return .orange
        }
    }

    var label: String {
        switch self {
        case .active: return "Actif"
        case .priority: return "Prioritaire"
        case .quote: return "Devis"
        }
    }
}



extension InterventionStatus {
    var label: String {
        switch self {
        case .planned: return "Planifiée"
        case .inProgress: return "En cours"
        case .completed: return "Terminée"
        }
    }

    var color: Color {
        switch self {
        case .planned: return .orange
        case .inProgress: return .blue
        case .completed: return .green
        }
    }
}

extension Quote {

    var statusValue: QuoteStatus {
        QuoteStatus(rawValue: status) ?? .pending
    }

    var documentTypeValue: QuoteDocumentType {
        QuoteDocumentType(rawValue: documentType) ?? .quote
    }
    
    
    var subtotal: Double {
        lines.reduce(0) { $0 + $1.quantity * $1.unitPrice }
    }

    var taxAmount: Double {
        subtotal * 0.2
    }

    var totalAmount: Double {
        subtotal + taxAmount
    }

    var depositAmount: Double {
        totalAmount * (depositRate / 100)
    }

    var amountPaid: Double {
        payments.reduce(0) { $0 + $1.amount }
    }

    var balanceDue: Double {
        totalAmount - amountPaid
    }
}

extension QuoteStatus {
    var color: Color {
        switch self {
        case .pending: return .orange
        case .sent: return .blue
        case .late: return .red
        case .paid: return .green
        }
    }
}



extension InventoryItem {

    var usedQuantity: Int {
        usages.reduce(0) { $0 + $1.quantityUsed }
    }

    var availableQuantity: Int {
        quantity - usedQuantity
    }

    var currentValue: Double {
        Double(availableQuantity) * unitCost
    }
    
    var levelValue: StockLevel {
        StockLevel(rawValue: stockLevel) ?? .normal
    }
    var color: Color {
        levelValue.color
    }
    
}

extension StockLevel {
    var color: Color {
        switch self {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }

    var label: String {
        switch self {
        case .normal: return "Normal"
        case .warning: return "Attention"
        case .critical: return "Critique"
        }
    }
}



extension Intervention {
    var priorityValue: PriorityLevel {
        PriorityLevel(rawValue: priority) ?? .normal
    }

    var statusValue: InterventionStatus {
        InterventionStatus(rawValue: status) ?? .planned
    }
    
    var isCompleted: Bool {
        status == "completed"
    }
    

    

    var dateLabel: String {
        if Calendar.current.isDateInToday(date) { return "Aujourd'hui" }
        if Calendar.current.isDateInTomorrow(date) { return "Demain" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
    
    
    
    
    
}
