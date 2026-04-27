import Foundation
import SwiftData
import SwiftUI

struct GestionViewState {
    let filteredClients: [ClientRecord]
    let filteredInterventions: [InterventionRecord]
    let filteredQuotes: [QuoteRecord]
    let filteredInventory: [InventoryItemRecord]
    let metrics: [DashboardMetric]
    let highlights: [DashboardHighlight]
    let upcomingInterventions: [InterventionRecord]
    let groupedInterventions: [(date: String, items: [InterventionRecord])]
    let todaysInterventionCount: Int
    let pendingQuoteCount: Int
    let criticalStockCount: Int
    let monthlyRevenue: Double
    let outstandingBalance: Double
}

enum WorkspaceTab: String, CaseIterable, Identifiable {
    case dashboard
    case planning
    case clients
    case interventions
    case quotes
    case inventory

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Tableau de bord"
        case .planning: return "Planning"
        case .clients: return "Clients"
        case .interventions: return "Interventions"
        case .quotes: return "Facturation"
        case .inventory: return "Stock"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "chart.bar"
        case .planning: return "calendar"
        case .clients: return "person.2"
        case .interventions: return "bolt.circle"
        case .quotes: return "doc.text"
        case .inventory: return "shippingbox"
        }
    }
}

enum PlanningFilter: String, CaseIterable, Identifiable {
    case all
    case week
    case open
    case completed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "Tout"
        case .week: return "Semaine"
        case .open: return "En cours"
        case .completed: return "Terminées"
        }
    }
}

enum EditorSheet: Identifiable {
    case client(ClientDraft)
    case intervention(InterventionDraft)
    case quote(QuoteDraft)
    case inventory(InventoryDraft)

    var id: String {
        switch self {
        case .client(let draft):
            return "client-\(draft.id.map { String(describing: $0) } ?? "new")"
        case .intervention(let draft):
            return "intervention-\(draft.id.map { String(describing: $0) } ?? "new")"
        case .quote(let draft):
            return "quote-\(draft.id.map { String(describing: $0) } ?? "new")"
        case .inventory(let draft):
            return "inventory-\(draft.id.map { String(describing: $0) } ?? "new")"
        }
    }
}

enum DeletionTarget: Identifiable {
    case client(PersistentIdentifier)
    case intervention(PersistentIdentifier)
    case quote(PersistentIdentifier)
    case inventory(PersistentIdentifier)

    var id: String {
        switch self {
        case .client(let id): return "client-\(id)"
        case .intervention(let id): return "intervention-\(id)"
        case .quote(let id): return "quote-\(id)"
        case .inventory(let id): return "inventory-\(id)"
        }
    }

    var kind: String {
        switch self {
        case .client: return "ce client"
        case .intervention: return "cette intervention"
        case .quote: return "ce document"
        case .inventory: return "cet article"
        }
    }
}

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

struct ClientOption: Identifiable, Hashable {
    let id: PersistentIdentifier
    let name: String
}

struct InventoryOption: Identifiable, Hashable {
    let id: PersistentIdentifier
    let name: String
    let sku: String
    let availableQuantity: Int
    let unitCost: Double
}

enum ClientStatus: String, CaseIterable, Identifiable {
    case active
    case priority
    case quote

    var id: String { rawValue }

    var label: String {
        switch self {
        case .active: return "Actif"
        case .priority: return "Prioritaire"
        case .quote: return "Devis"
        }
    }

    var color: Color {
        switch self {
        case .active: return .blue
        case .priority: return .green
        case .quote: return .orange
        }
    }
}

enum PriorityLevel: String, CaseIterable, Identifiable {
    case urgent
    case normal
    case quote

    var id: String { rawValue }

    var label: String {
        switch self {
        case .urgent: return "Urgent"
        case .normal: return "Planifié"
        case .quote: return "Étude"
        }
    }

    var color: Color {
        switch self {
        case .urgent: return .red
        case .normal: return .blue
        case .quote: return .orange
        }
    }
}

enum InterventionStatus: String, CaseIterable, Identifiable {
    case planned
    case inProgress
    case completed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .planned: return "Planifiée"
        case .inProgress: return "En cours"
        case .completed: return "Terminée"
        }
    }

    var color: Color {
        switch self {
        case .planned: return .blue
        case .inProgress: return .orange
        case .completed: return .green
        }
    }
}

enum QuoteStatus: String, CaseIterable, Identifiable {
    case pending
    case sent
    case late
    case paid

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pending: return "À valider"
        case .sent: return "Envoyée"
        case .late: return "Relance"
        case .paid: return "Réglée"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .orange
        case .sent: return .blue
        case .late: return .red
        case .paid: return .green
        }
    }

    var icon: String {
        switch self {
        case .pending: return "doc.badge.clock"
        case .sent: return "paperplane"
        case .late: return "exclamationmark.arrow.trianglehead.counterclockwise"
        case .paid: return "checkmark.seal"
        }
    }
}

enum QuoteDocumentType: String, CaseIterable, Identifiable {
    case quote
    case invoice

    var id: String { rawValue }

    var label: String {
        switch self {
        case .quote: return "Devis"
        case .invoice: return "Facture"
        }
    }
}

enum PaymentMethod: String, CaseIterable, Identifiable {
    case transfer
    case cash
    case card
    case check

    var id: String { rawValue }

    var label: String {
        switch self {
        case .transfer: return "Virement"
        case .cash: return "Espèces"
        case .card: return "Carte"
        case .check: return "Chèque"
        }
    }
}

enum StockLevel: String, CaseIterable, Identifiable {
    case normal
    case warning
    case critical

    var id: String { rawValue }

    var label: String {
        switch self {
        case .normal: return "Disponible"
        case .warning: return "À suivre"
        case .critical: return "Rupture proche"
        }
    }

    var color: Color {
        switch self {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

enum InventoryMovementType: String, CaseIterable, Identifiable {
    case entry
    case adjustment
    case returnFromSite

    var id: String { rawValue }

    var label: String {
        switch self {
        case .entry: return "Entrée"
        case .adjustment: return "Ajustement"
        case .returnFromSite: return "Retour chantier"
        }
    }
}

@Model
final class ClientRecord {
    var name: String
    var city: String
    var note: String
    var status: String
    var phone: String
    var email: String
    var address: String

    @Relationship(deleteRule: .nullify, inverse: \InterventionRecord.client)
    var interventions: [InterventionRecord] = []

    @Relationship(deleteRule: .nullify, inverse: \QuoteRecord.client)
    var quotes: [QuoteRecord] = []

    init(name: String, city: String, note: String, status: String, phone: String, email: String, address: String) {
        self.name = name
        self.city = city
        self.note = note
        self.status = status
        self.phone = phone
        self.email = email
        self.address = address
    }

    var statusValue: ClientStatus { ClientStatus(rawValue: status) ?? .active }
    var outstandingBalance: Double { quotes.reduce(0) { $0 + $1.balanceDue } }
}

@Model
final class InterventionRecord {
    var clientName: String
    var location: String
    var kind: String
    var date: Date
    var timeSlot: String
    var priority: String
    var progress: Double
    var notes: String
    var sortDate: Date
    var executionStatus: String

    var client: ClientRecord?

    @Relationship(deleteRule: .cascade, inverse: \StockUsageRecord.intervention)
    var stockUsages: [StockUsageRecord] = []

    init(
        clientName: String,
        location: String,
        kind: String,
        date: Date,
        timeSlot: String,
        priority: String,
        progress: Double,
        notes: String,
        executionStatus: String,
        client: ClientRecord? = nil
    ) {
        self.clientName = clientName
        self.location = location
        self.kind = kind
        self.date = date
        self.timeSlot = timeSlot
        self.priority = priority
        self.progress = progress
        self.notes = notes
        self.sortDate = date
        self.executionStatus = executionStatus
        self.client = client
    }

    var priorityValue: PriorityLevel { PriorityLevel(rawValue: priority) ?? .normal }
    var statusValue: InterventionStatus { InterventionStatus(rawValue: executionStatus) ?? .planned }
    var dateLabel: String { date.gestionDayLabel }
    var shortDateLabel: String { date.gestionShortDayLabel }
    var usedItemsCount: Int { stockUsages.reduce(0) { $0 + $1.quantityUsed } }
    var usedItemsCost: Double { stockUsages.reduce(0) { $0 + $1.totalCost } }
}

@Model
final class QuoteRecord {
    var reference: String
    var clientName: String
    var dueDate: String
    var status: String
    var summary: String
    var documentType: String
    var depositRate: Double

    var client: ClientRecord?

    @Relationship(deleteRule: .cascade, inverse: \QuoteLineRecord.quote)
    var lines: [QuoteLineRecord] = []

    @Relationship(deleteRule: .cascade, inverse: \PaymentRecord.quote)
    var payments: [PaymentRecord] = []

    init(
        reference: String,
        clientName: String,
        dueDate: String,
        status: String,
        summary: String,
        documentType: String,
        depositRate: Double,
        client: ClientRecord? = nil
    ) {
        self.reference = reference
        self.clientName = clientName
        self.dueDate = dueDate
        self.status = status
        self.summary = summary
        self.documentType = documentType
        self.depositRate = depositRate
        self.client = client
    }

    var statusValue: QuoteStatus { QuoteStatus(rawValue: status) ?? .pending }
    var documentTypeValue: QuoteDocumentType { QuoteDocumentType(rawValue: documentType) ?? .quote }
    var subtotal: Double { lines.reduce(0) { $0 + $1.subtotal } }
    var taxAmount: Double { lines.reduce(0) { $0 + $1.taxAmount } }
    var totalAmount: Double { subtotal + taxAmount }
    var depositAmount: Double { totalAmount * depositRate / 100 }
    var amountPaid: Double { payments.reduce(0) { $0 + $1.amount } }
    var balanceDue: Double { max(totalAmount - amountPaid, 0) }
    var formattedAmount: String { totalAmount.formattedEuro }
}

@Model
final class QuoteLineRecord {
    var title: String
    var lineDescription: String
    var quantity: Double
    var unitPrice: Double
    var taxRate: Double

    var quote: QuoteRecord?

    init(title: String, lineDescription: String, quantity: Double, unitPrice: Double, taxRate: Double, quote: QuoteRecord? = nil) {
        self.title = title
        self.lineDescription = lineDescription
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.taxRate = taxRate
        self.quote = quote
    }

    var subtotal: Double { quantity * unitPrice }
    var taxAmount: Double { subtotal * taxRate / 100 }
    var totalAmount: Double { subtotal + taxAmount }
}

@Model
final class PaymentRecord {
    var paidAt: Date
    var amount: Double
    var method: String
    var note: String

    var quote: QuoteRecord?

    init(paidAt: Date, amount: Double, method: String, note: String, quote: QuoteRecord? = nil) {
        self.paidAt = paidAt
        self.amount = amount
        self.method = method
        self.note = note
        self.quote = quote
    }

    var methodValue: PaymentMethod { PaymentMethod(rawValue: method) ?? .transfer }
}

@Model
final class InventoryItemRecord {
    var name: String
    var sku: String
    var quantity: Int
    var stockLevel: String
    var supplier: String
    var storageLocation: String
    var minimumQuantity: Int
    var unitCost: Double

    @Relationship(deleteRule: .nullify, inverse: \StockUsageRecord.inventoryItem)
    var usages: [StockUsageRecord] = []

    @Relationship(deleteRule: .cascade, inverse: \InventoryMovementRecord.inventoryItem)
    var movements: [InventoryMovementRecord] = []

    init(
        name: String,
        sku: String,
        quantity: Int,
        stockLevel: String,
        supplier: String,
        storageLocation: String,
        minimumQuantity: Int,
        unitCost: Double
    ) {
        self.name = name
        self.sku = sku
        self.quantity = quantity
        self.stockLevel = stockLevel
        self.supplier = supplier
        self.storageLocation = storageLocation
        self.minimumQuantity = minimumQuantity
        self.unitCost = unitCost
    }

    var usedQuantity: Int { usages.reduce(0) { $0 + $1.quantityUsed } }
    var movementDelta: Int { movements.reduce(0) { $0 + $1.quantityDelta } }
    var availableQuantity: Int { max(quantity + movementDelta - usedQuantity, 0) }
    var currentValue: Double { Double(availableQuantity) * unitCost }

    var levelValue: StockLevel {
        if availableQuantity <= minimumQuantity { return .critical }
        if availableQuantity <= minimumQuantity + 5 { return .warning }
        return StockLevel(rawValue: stockLevel) ?? .normal
    }
}

@Model
final class InventoryMovementRecord {
    var movedAt: Date
    var quantityDelta: Int
    var type: String
    var note: String

    var inventoryItem: InventoryItemRecord?

    init(movedAt: Date, quantityDelta: Int, type: String, note: String, inventoryItem: InventoryItemRecord? = nil) {
        self.movedAt = movedAt
        self.quantityDelta = quantityDelta
        self.type = type
        self.note = note
        self.inventoryItem = inventoryItem
    }

    var typeValue: InventoryMovementType { InventoryMovementType(rawValue: type) ?? .adjustment }
}

@Model
final class StockUsageRecord {
    var inventoryItemName: String
    var quantityUsed: Int
    var unitCost: Double

    var intervention: InterventionRecord?
    var inventoryItem: InventoryItemRecord?

    init(inventoryItemName: String, quantityUsed: Int, unitCost: Double, intervention: InterventionRecord? = nil, inventoryItem: InventoryItemRecord? = nil) {
        self.inventoryItemName = inventoryItemName
        self.quantityUsed = quantityUsed
        self.unitCost = unitCost
        self.intervention = intervention
        self.inventoryItem = inventoryItem
    }

    var totalCost: Double { unitCost * Double(quantityUsed) }
}

struct ClientDraft {
    var id: PersistentIdentifier?
    var name = ""
    var city = ""
    var note = ""
    var status: ClientStatus = .active
    var phone = ""
    var email = ""
    var address = ""

    init() {}

    init(client: ClientRecord) {
        id = client.persistentModelID
        name = client.name
        city = client.city
        note = client.note
        status = client.statusValue
        phone = client.phone
        email = client.email
        address = client.address
    }

    func makeClient() -> ClientRecord {
        ClientRecord(name: name, city: city, note: note, status: status.rawValue, phone: phone, email: email, address: address)
    }
}

struct StockUsageDraft: Identifiable {
    let id = UUID()
    var inventoryItemID: PersistentIdentifier?
    var inventoryItemName = ""
    var quantityUsed = 1
    var unitCost = 0.0

    init() {}

    @MainActor init(usage: StockUsageRecord) {
        inventoryItemID = usage.inventoryItem?.persistentModelID
        inventoryItemName = usage.inventoryItemName
        quantityUsed = usage.quantityUsed
        unitCost = usage.unitCost
    }
}

struct InterventionDraft {
    var id: PersistentIdentifier?
    var clientID: PersistentIdentifier?
    var clientName = ""
    var location = ""
    var kind = ""
    var scheduledDate = Calendar.current.startOfDay(for: .now)
    var timeSlot = "08:00 - 10:00"
    var priority: PriorityLevel = .normal
    var executionStatus: InterventionStatus = .planned
    var progress = 0.0
    var notes = ""
    var stockUsages: [StockUsageDraft] = []

    init() {}

    @MainActor init(intervention: InterventionRecord) {
        id = intervention.persistentModelID
        clientID = intervention.client?.persistentModelID
        clientName = intervention.clientName
        location = intervention.location
        kind = intervention.kind
        scheduledDate = intervention.date
        timeSlot = intervention.timeSlot
        priority = intervention.priorityValue
        executionStatus = intervention.statusValue
        progress = intervention.progress
        notes = intervention.notes
        stockUsages = intervention.stockUsages.map(StockUsageDraft.init)
    }

    var sortDate: Date { scheduledDate }
}

struct QuoteLineDraft: Identifiable {
    let id = UUID()
    var title = ""
    var lineDescription = ""
    var quantity = 1.0
    var unitPrice = 0.0
    var taxRate = 20.0

    init() {}

    @MainActor init(line: QuoteLineRecord) {
        title = line.title
        lineDescription = line.lineDescription
        quantity = line.quantity
        unitPrice = line.unitPrice
        taxRate = line.taxRate
    }

    var subtotal: Double { quantity * unitPrice }
}

struct PaymentDraft: Identifiable {
    let id = UUID()
    var paidAt = Date()
    var amount = 0.0
    var method: PaymentMethod = .transfer
    var note = ""

    init() {}

    @MainActor init(payment: PaymentRecord) {
        paidAt = payment.paidAt
        amount = payment.amount
        method = payment.methodValue
        note = payment.note
    }
}

struct QuoteDraft {
    var id: PersistentIdentifier?
    var clientID: PersistentIdentifier?
    var reference = ""
    var clientName = ""
    var dueDate = ""
    var status: QuoteStatus = .pending
    var summary = ""
    var documentType: QuoteDocumentType = .quote
    var depositRate = 30.0
    var lines: [QuoteLineDraft] = [QuoteLineDraft()]
    var payments: [PaymentDraft] = []

    init() {}

    @MainActor init(quote: QuoteRecord) {
        id = quote.persistentModelID
        clientID = quote.client?.persistentModelID
        reference = quote.reference
        clientName = quote.clientName
        dueDate = quote.dueDate
        status = quote.statusValue
        summary = quote.summary
        documentType = quote.documentTypeValue
        depositRate = quote.depositRate
        lines = quote.lines.isEmpty ? [QuoteLineDraft()] : quote.lines.map(QuoteLineDraft.init)
        payments = quote.payments.map(PaymentDraft.init)
    }

    var subtotal: Double { lines.reduce(0) { $0 + $1.subtotal } }
    var taxAmount: Double { lines.reduce(0) { $0 + ($1.subtotal * $1.taxRate / 100) } }
    var totalAmount: Double { subtotal + taxAmount }
    var amountPaid: Double { payments.reduce(0) { $0 + $1.amount } }
    var balanceDue: Double { max(totalAmount - amountPaid, 0) }
}

struct InventoryMovementDraft: Identifiable {
    let id = UUID()
    var movedAt = Date()
    var quantityDelta = 0
    var type: InventoryMovementType = .entry
    var note = ""

    init() {}

    @MainActor init(movement: InventoryMovementRecord) {
        movedAt = movement.movedAt
        quantityDelta = movement.quantityDelta
        type = movement.typeValue
        note = movement.note
    }
}

struct InventoryDraft {
    var id: PersistentIdentifier?
    var name = ""
    var sku = ""
    var quantity = 0
    var level: StockLevel = .normal
    var supplier = ""
    var storageLocation = ""
    var minimumQuantity = 0
    var unitCost = 0.0
    var movements: [InventoryMovementDraft] = []

    init() {}

    @MainActor init(item: InventoryItemRecord) {
        id = item.persistentModelID
        name = item.name
        sku = item.sku
        quantity = item.quantity
        level = item.levelValue
        supplier = item.supplier
        storageLocation = item.storageLocation
        minimumQuantity = item.minimumQuantity
        unitCost = item.unitCost
        movements = item.movements.map(InventoryMovementDraft.init)
    }

    var inferredLevel: StockLevel {
        if quantity <= minimumQuantity { return .critical }
        if quantity <= minimumQuantity + 5 { return .warning }
        return level
    }

    func makeItem() -> InventoryItemRecord {
        InventoryItemRecord(
            name: name,
            sku: sku,
            quantity: quantity,
            stockLevel: inferredLevel.rawValue,
            supplier: supplier,
            storageLocation: storageLocation,
            minimumQuantity: minimumQuantity,
            unitCost: unitCost
        )
    }
}

enum SampleData {
    static func populate(in modelContext: ModelContext) {
        let residence = ClientRecord(
            name: "Résidence Les Tilleuls",
            city: "Nîmes",
            note: "Contrat maintenance parties communes",
            status: ClientStatus.priority.rawValue,
            phone: "06 10 10 10 10",
            email: "syndic@tilleuls.fr",
            address: "14 avenue des Tilleuls, 30000 Nîmes"
        )

        let bakery = ClientRecord(
            name: "Boulangerie Morel",
            city: "Uzès",
            note: "Remise aux normes du tableau électrique",
            status: ClientStatus.active.rawValue,
            phone: "06 20 20 20 20",
            email: "contact@boulangerie-morel.fr",
            address: "8 place du marché, 30700 Uzès"
        )

        let durand = ClientRecord(
            name: "M. Durand",
            city: "Alès",
            note: "Installation borne de recharge prévue",
            status: ClientStatus.quote.rawValue,
            phone: "06 30 30 30 30",
            email: "durand@orange.fr",
            address: "22 chemin des Vignes, 30100 Alès"
        )

        let breaker = InventoryItemRecord(
            name: "Disjoncteur 20A Legrand",
            sku: "DJ-20A-LG",
            quantity: 14,
            stockLevel: StockLevel.normal.rawValue,
            supplier: "Rexel Nîmes",
            storageLocation: "Camionnette A",
            minimumQuantity: 5,
            unitCost: 18.5
        )

        let ledSpot = InventoryItemRecord(
            name: "Spots LED IP65",
            sku: "LED-IP65",
            quantity: 24,
            stockLevel: StockLevel.normal.rawValue,
            supplier: "Sonepar",
            storageLocation: "Dépôt principal",
            minimumQuantity: 8,
            unitCost: 11.9
        )

        let cable = InventoryItemRecord(
            name: "Gaine ICTA 20 mm",
            sku: "ICTA-20",
            quantity: 10,
            stockLevel: StockLevel.warning.rawValue,
            supplier: "CGED",
            storageLocation: "Rayon câblage",
            minimumQuantity: 4,
            unitCost: 4.3
        )

        breaker.movements = [
            InventoryMovementRecord(movedAt: .now, quantityDelta: 6, type: InventoryMovementType.entry.rawValue, note: "Réception commande grossiste", inventoryItem: breaker)
        ]
        ledSpot.movements = [
            InventoryMovementRecord(movedAt: .now, quantityDelta: 12, type: InventoryMovementType.entry.rawValue, note: "Entrée dépôt LED", inventoryItem: ledSpot)
        ]

        let coldRoom = InterventionRecord(
            clientName: bakery.name,
            location: "Uzès",
            kind: "Dépannage chambre froide",
            date: .now,
            timeSlot: "08:30 - 10:00",
            priority: PriorityLevel.urgent.rawValue,
            progress: 0.85,
            notes: "Contrôle des protections et remplacement d'un contacteur.",
            executionStatus: InterventionStatus.inProgress.rawValue,
            client: bakery
        )

        let lights = InterventionRecord(
            clientName: residence.name,
            location: "Nîmes",
            kind: "Maintenance éclairage hall",
            date: .now,
            timeSlot: "10:30 - 12:00",
            priority: PriorityLevel.normal.rawValue,
            progress: 1.0,
            notes: "Vérification minuterie et remplacement de deux luminaires.",
            executionStatus: InterventionStatus.completed.rawValue,
            client: residence
        )

        let irve = InterventionRecord(
            clientName: durand.name,
            location: "Alès",
            kind: "Visite technique borne IRVE",
            date: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now,
            timeSlot: "14:00 - 15:30",
            priority: PriorityLevel.quote.rawValue,
            progress: 0.20,
            notes: "Relevé puissance disponible et passage de câble.",
            executionStatus: InterventionStatus.planned.rawValue,
            client: durand
        )

        coldRoom.stockUsages = [
            StockUsageRecord(inventoryItemName: breaker.name, quantityUsed: 2, unitCost: breaker.unitCost, intervention: coldRoom, inventoryItem: breaker)
        ]
        lights.stockUsages = [
            StockUsageRecord(inventoryItemName: ledSpot.name, quantityUsed: 6, unitCost: ledSpot.unitCost, intervention: lights, inventoryItem: ledSpot),
            StockUsageRecord(inventoryItemName: cable.name, quantityUsed: 2, unitCost: cable.unitCost, intervention: lights, inventoryItem: cable)
        ]

        let quote = QuoteRecord(
            reference: "DEV-2026-014",
            clientName: durand.name,
            dueDate: "28 avr.",
            status: QuoteStatus.pending.rawValue,
            summary: "Fourniture et pose d'une borne de recharge 7,4 kW avec protection dédiée.",
            documentType: QuoteDocumentType.quote.rawValue,
            depositRate: 30,
            client: durand
        )

        let invoiceResidence = QuoteRecord(
            reference: "FAC-2026-031",
            clientName: residence.name,
            dueDate: "30 avr.",
            status: QuoteStatus.sent.rawValue,
            summary: "Maintenance annuelle et remise en état des luminaires.",
            documentType: QuoteDocumentType.invoice.rawValue,
            depositRate: 0,
            client: residence
        )

        let invoiceBakery = QuoteRecord(
            reference: "FAC-2026-027",
            clientName: bakery.name,
            dueDate: "22 avr.",
            status: QuoteStatus.late.rawValue,
            summary: "Dépannage et sécurisation de l'alimentation de la chambre froide.",
            documentType: QuoteDocumentType.invoice.rawValue,
            depositRate: 0,
            client: bakery
        )

        quote.lines = [
            QuoteLineRecord(title: "Borne 7,4 kW", lineDescription: "Fourniture et pose de la borne", quantity: 1, unitPrice: 1490, taxRate: 20, quote: quote),
            QuoteLineRecord(title: "Protection tableau", lineDescription: "Disjoncteur, différentiel, câblage", quantity: 1, unitPrice: 690, taxRate: 20, quote: quote),
            QuoteLineRecord(title: "Mise en service", lineDescription: "Essais et attestation", quantity: 1, unitPrice: 220, taxRate: 20, quote: quote)
        ]
        quote.payments = [
            PaymentRecord(paidAt: .now, amount: 450, method: PaymentMethod.transfer.rawValue, note: "Acompte réservation", quote: quote)
        ]

        invoiceResidence.lines = [
            QuoteLineRecord(title: "Contrat maintenance", lineDescription: "Visite annuelle copropriété", quantity: 1, unitPrice: 2200, taxRate: 20, quote: invoiceResidence),
            QuoteLineRecord(title: "Remplacement luminaires", lineDescription: "6 luminaires LED hall", quantity: 6, unitPrice: 110, taxRate: 20, quote: invoiceResidence)
        ]
        invoiceResidence.payments = [
            PaymentRecord(paidAt: .now, amount: 1800, method: PaymentMethod.transfer.rawValue, note: "Règlement partiel syndic", quote: invoiceResidence)
        ]

        invoiceBakery.lines = [
            QuoteLineRecord(title: "Dépannage électrique", lineDescription: "Recherche de panne et remise en service", quantity: 3, unitPrice: 95, taxRate: 20, quote: invoiceBakery),
            QuoteLineRecord(title: "Matériel de protection", lineDescription: "Disjoncteurs et consommables", quantity: 1, unitPrice: 180, taxRate: 20, quote: invoiceBakery)
        ]

        modelContext.insert(residence)
        modelContext.insert(bakery)
        modelContext.insert(durand)
        modelContext.insert(breaker)
        modelContext.insert(ledSpot)
        modelContext.insert(cable)
        modelContext.insert(coldRoom)
        modelContext.insert(lights)
        modelContext.insert(irve)
        modelContext.insert(quote)
        modelContext.insert(invoiceResidence)
        modelContext.insert(invoiceBakery)
    }
}
