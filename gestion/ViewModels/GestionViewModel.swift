import Foundation
import Observation
import SwiftData
import SwiftUI

@Observable
final class GestionViewModel {
    var selectedTab: WorkspaceTab = .dashboard
    var planningFilter: PlanningFilter = .all
    var searchText = ""
    var activeSheet: EditorSheet?
    var deletionTarget: DeletionTarget?
    var quoteToExport: QuoteRecord?
    var exportDocument: PDFFileDocument?
    var isShowingExporter = false

    private let seedKey = "hasSeededSampleDataV3"

    private var hasSeededSampleData: Bool {
        get { UserDefaults.standard.bool(forKey: seedKey) }
        set { UserDefaults.standard.set(newValue, forKey: seedKey) }
    }

    var canAddCurrentTabItem: Bool {
        selectedTab != .dashboard && selectedTab != .planning
    }

    func makeViewState(
        clients: [ClientRecord],
        interventions: [InterventionRecord],
        quotes: [QuoteRecord],
        inventory: [InventoryItemRecord]
    ) -> GestionViewState {
        let filteredClients = filterClients(clients)
        let filteredInterventions = filterInterventions(interventions)
        let filteredQuotes = filterQuotes(quotes)
        let filteredInventory = filterInventory(inventory)
        let sortedInterventions = interventions.sorted { $0.sortDate < $1.sortDate }
        let groupedInterventions = groupInterventions(filteredInterventions)

        var monthlyRevenue = 0.0
        var outstandingBalance = 0.0
        var pendingCount = 0
        var lateCount = 0
        var paidCount = 0
        for quote in quotes {
            if quote.documentTypeValue == .invoice {
                monthlyRevenue += quote.amountPaid
                outstandingBalance += quote.balanceDue
            }
            switch quote.statusValue {
            case .pending:
                pendingCount += 1
            case .late:
                lateCount += 1
            case .paid:
                paidCount += 1
            case .sent:
                break
            }
        }

        var urgentCount = 0
        var todayCount = 0
        var completedCount = 0
        var stockCostToday = 0.0
        for intervention in interventions {
            if intervention.priorityValue == .urgent { urgentCount += 1 }
            if intervention.statusValue == .completed { completedCount += 1 }
            if Calendar.current.isDateInToday(intervention.sortDate) {
                todayCount += 1
                stockCostToday += intervention.usedItemsCost
            }
        }

        var criticalCount = 0
        var warningCount = 0
        var allocatedUnits = 0
        var inventoryValue = 0.0
        for item in inventory {
            switch item.levelValue {
            case .critical: criticalCount += 1
            case .warning: warningCount += 1
            case .normal: break
            }
            allocatedUnits += item.usedQuantity
            inventoryValue += item.currentValue
        }

        let metrics = [
            DashboardMetric(title: "Encaissements suivis", value: monthlyRevenue.formattedEuro, detail: "\(paidCount) factures réglées", icon: "eurosign.circle.fill", color: .green),
            DashboardMetric(title: "Reste à encaisser", value: outstandingBalance.formattedEuro, detail: "\(lateCount) relances, \(pendingCount) validations", icon: "creditcard.trianglebadge.exclamationmark", color: .orange),
            DashboardMetric(title: "Planning", value: "\(interventions.count)", detail: "\(completedCount) terminées, \(urgentCount) urgentes", icon: "calendar.circle.fill", color: .blue),
            DashboardMetric(title: "Stock valorisé", value: inventoryValue.formattedEuro, detail: "\(criticalCount) références critiques", icon: "shippingbox.circle.fill", color: .red)
        ]

        let highlights = [
            DashboardHighlight(title: "Matériel engagé aujourd'hui", detail: stockCostToday.formattedEuro, icon: "shippingbox.and.arrow.backward", color: .orange),
            DashboardHighlight(title: "Planning semaine", detail: "\(interventionsThisWeek(interventions)) interventions", icon: "calendar.badge.clock", color: .blue),
            DashboardHighlight(title: "Surveillance stock", detail: "\(warningCount) références à suivre", icon: "exclamationmark.triangle", color: .yellow)
        ]

        return GestionViewState(
            filteredClients: filteredClients,
            filteredInterventions: filteredInterventions,
            filteredQuotes: filteredQuotes,
            filteredInventory: filteredInventory,
            metrics: metrics,
            highlights: highlights,
            upcomingInterventions: sortedInterventions,
            groupedInterventions: groupedInterventions,
            todaysInterventionCount: todayCount,
            pendingQuoteCount: pendingCount,
            criticalStockCount: criticalCount,
            monthlyRevenue: monthlyRevenue,
            outstandingBalance: outstandingBalance
        )
    }

    func clientOptions(from clients: [ClientRecord]) -> [ClientOption] {
        clients.sorted { $0.name < $1.name }.map { ClientOption(id: $0.persistentModelID, name: $0.name) }
    }

    func inventoryOptions(from inventory: [InventoryItemRecord]) -> [InventoryOption] {
        inventory.sorted { $0.name < $1.name }.map {
            InventoryOption(
                id: $0.persistentModelID,
                name: $0.name,
                sku: $0.sku,
                availableQuantity: $0.availableQuantity,
                unitCost: $0.unitCost
            )
        }
    }

    func presentNewForm() {
        switch selectedTab {
        case .dashboard, .planning:
            break
        case .clients:
            activeSheet = .client(ClientDraft())
        case .interventions:
            activeSheet = .intervention(InterventionDraft())
        case .quotes:
            activeSheet = .quote(QuoteDraft())
        case .inventory:
            activeSheet = .inventory(InventoryDraft())
        }
    }

    func delete(_ target: DeletionTarget, in modelContext: ModelContext) {
        switch target {
        case .client(let id):
            if let object = modelContext.model(for: id) as? ClientRecord { modelContext.delete(object) }
        case .intervention(let id):
            if let object = modelContext.model(for: id) as? InterventionRecord { modelContext.delete(object) }
        case .quote(let id):
            if let object = modelContext.model(for: id) as? QuoteRecord { modelContext.delete(object) }
        case .inventory(let id):
            if let object = modelContext.model(for: id) as? InventoryItemRecord { modelContext.delete(object) }
        }
        try? modelContext.save()
    }

    func saveClient(_ draft: ClientDraft, in modelContext: ModelContext) {
        if let id = draft.id, let client = modelContext.model(for: id) as? ClientRecord {
            client.name = draft.name
            client.city = draft.city
            client.note = draft.note
            client.status = draft.status.rawValue
            client.phone = draft.phone
            client.email = draft.email
            client.address = draft.address
        } else {
            modelContext.insert(draft.makeClient())
        }
        try? modelContext.save()
    }

    func saveIntervention(_ draft: InterventionDraft, in modelContext: ModelContext) {
        let client = draft.clientID.flatMap { modelContext.model(for: $0) as? ClientRecord }

        let intervention: InterventionRecord
        if let id = draft.id, let existing = modelContext.model(for: id) as? InterventionRecord {
            intervention = existing
            intervention.stockUsages.forEach { modelContext.delete($0) }
        } else {
            intervention = InterventionRecord(
                clientName: draft.clientName,
                location: draft.location,
                kind: draft.kind,
                date: draft.scheduledDate,
                timeSlot: draft.timeSlot,
                priority: draft.priority.rawValue,
                progress: draft.progress,
                notes: draft.notes,
                executionStatus: draft.executionStatus.rawValue,
                client: client
            )
            modelContext.insert(intervention)
        }

        intervention.client = client
        intervention.clientName = draft.clientName
        intervention.location = draft.location
        intervention.kind = draft.kind
        intervention.date = draft.scheduledDate
        intervention.timeSlot = draft.timeSlot
        intervention.priority = draft.priority.rawValue
        intervention.executionStatus = draft.executionStatus.rawValue
        intervention.progress = draft.progress
        intervention.notes = draft.notes
        intervention.sortDate = draft.sortDate
        intervention.stockUsages = draft.stockUsages.compactMap { usage in
            guard usage.quantityUsed > 0 else { return nil }
            let inventory = usage.inventoryItemID.flatMap { modelContext.model(for: $0) as? InventoryItemRecord }
            return StockUsageRecord(
                inventoryItemName: inventory?.name ?? usage.inventoryItemName,
                quantityUsed: usage.quantityUsed,
                unitCost: inventory?.unitCost ?? usage.unitCost,
                intervention: intervention,
                inventoryItem: inventory
            )
        }
        try? modelContext.save()
    }

    func saveQuote(_ draft: QuoteDraft, in modelContext: ModelContext) {
        let client = draft.clientID.flatMap { modelContext.model(for: $0) as? ClientRecord }

        let quote: QuoteRecord
        if let id = draft.id, let existing = modelContext.model(for: id) as? QuoteRecord {
            quote = existing
            quote.lines.forEach { modelContext.delete($0) }
            quote.payments.forEach { modelContext.delete($0) }
        } else {
            quote = QuoteRecord(
                reference: draft.reference,
                clientName: draft.clientName,
                dueDate: draft.dueDate,
                status: draft.status.rawValue,
                summary: draft.summary,
                documentType: draft.documentType.rawValue,
                depositRate: draft.depositRate,
                client: client
            )
            modelContext.insert(quote)
        }

        quote.client = client
        quote.reference = draft.reference
        quote.clientName = draft.clientName
        quote.dueDate = draft.dueDate
        quote.status = draft.status.rawValue
        quote.summary = draft.summary
        quote.documentType = draft.documentType.rawValue
        quote.depositRate = draft.depositRate
        quote.lines = draft.lines.compactMap { line in
            guard !line.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return QuoteLineRecord(
                title: line.title,
                lineDescription: line.lineDescription,
                quantity: line.quantity,
                unitPrice: line.unitPrice,
                taxRate: line.taxRate,
                quote: quote
            )
        }
        quote.payments = draft.payments.compactMap { payment in
            guard payment.amount > 0 else { return nil }
            return PaymentRecord(
                paidAt: payment.paidAt,
                amount: payment.amount,
                method: payment.method.rawValue,
                note: payment.note,
                quote: quote
            )
        }
        if quote.balanceDue == 0, quote.totalAmount > 0 {
            quote.status = QuoteStatus.paid.rawValue
        }
        try? modelContext.save()
    }

    func saveInventory(_ draft: InventoryDraft, in modelContext: ModelContext) {
        let item: InventoryItemRecord
        if let id = draft.id, let existing = modelContext.model(for: id) as? InventoryItemRecord {
            item = existing
            item.movements.forEach { modelContext.delete($0) }
        } else {
            item = draft.makeItem()
            modelContext.insert(item)
        }

        item.name = draft.name
        item.sku = draft.sku
        item.quantity = draft.quantity
        item.stockLevel = draft.inferredLevel.rawValue
        item.supplier = draft.supplier
        item.storageLocation = draft.storageLocation
        item.minimumQuantity = draft.minimumQuantity
        item.unitCost = draft.unitCost
        item.movements = draft.movements.compactMap { movement in
            guard movement.quantityDelta != 0 else { return nil }
            return InventoryMovementRecord(
                movedAt: movement.movedAt,
                quantityDelta: movement.quantityDelta,
                type: movement.type.rawValue,
                note: movement.note,
                inventoryItem: item
            )
        }
        try? modelContext.save()
    }

    func exportPDF(for quote: QuoteRecord) {
        exportDocument = PDFFileDocument(data: PDFRenderer.renderQuotePDF(for: quote))
        quoteToExport = quote
        isShowingExporter = true
    }

    func clearExportState() {
        quoteToExport = nil
        exportDocument = nil
    }

    func seedDataIfNeeded(
        clients: [ClientRecord],
        interventions: [InterventionRecord],
        quotes: [QuoteRecord],
        inventory: [InventoryItemRecord],
        in modelContext: ModelContext
    ) {
        guard !hasSeededSampleData else { return }
        guard clients.isEmpty, interventions.isEmpty, quotes.isEmpty, inventory.isEmpty else {
            hasSeededSampleData = true
            return
        }
        SampleData.populate(in: modelContext)
        try? modelContext.save()
        hasSeededSampleData = true
    }

    private func filterClients(_ clients: [ClientRecord]) -> [ClientRecord] {
        guard !searchText.isEmpty else { return clients }
        return clients.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
            || $0.city.localizedCaseInsensitiveContains(searchText)
            || $0.phone.localizedCaseInsensitiveContains(searchText)
            || $0.quotes.contains { $0.reference.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private func filterInterventions(_ interventions: [InterventionRecord]) -> [InterventionRecord] {
        let base = planningFiltered(interventions)
        guard !searchText.isEmpty else { return base }
        return base.filter {
            $0.clientName.localizedCaseInsensitiveContains(searchText)
            || $0.location.localizedCaseInsensitiveContains(searchText)
            || $0.kind.localizedCaseInsensitiveContains(searchText)
            || $0.stockUsages.contains { $0.inventoryItemName.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private func filterQuotes(_ quotes: [QuoteRecord]) -> [QuoteRecord] {
        guard !searchText.isEmpty else { return quotes }
        return quotes.filter {
            $0.reference.localizedCaseInsensitiveContains(searchText)
            || $0.clientName.localizedCaseInsensitiveContains(searchText)
            || $0.lines.contains { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private func filterInventory(_ inventory: [InventoryItemRecord]) -> [InventoryItemRecord] {
        guard !searchText.isEmpty else { return inventory }
        return inventory.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
            || $0.sku.localizedCaseInsensitiveContains(searchText)
            || $0.supplier.localizedCaseInsensitiveContains(searchText)
            || $0.usages.contains { $0.inventoryItemName.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private func planningFiltered(_ interventions: [InterventionRecord]) -> [InterventionRecord] {
        switch planningFilter {
        case .all:
            return interventions
        case .week:
            return interventions.filter { Calendar.current.isDate($0.sortDate, equalTo: .now, toGranularity: .weekOfYear) }
        case .open:
            return interventions.filter { $0.statusValue != .completed }
        case .completed:
            return interventions.filter { $0.statusValue == .completed }
        }
    }

    private func groupInterventions(_ interventions: [InterventionRecord]) -> [(date: String, items: [InterventionRecord])] {
        let grouped = Dictionary(grouping: interventions) { $0.dateLabel }
        return grouped.keys.sorted(by: daySort).map { key in
            let items = (grouped[key] ?? []).sorted { $0.timeSlot < $1.timeSlot }
            return (key, items)
        }
    }

    private func interventionsThisWeek(_ interventions: [InterventionRecord]) -> Int {
        interventions.filter { Calendar.current.isDate($0.sortDate, equalTo: .now, toGranularity: .weekOfYear) }.count
    }

    private func daySort(lhs: String, rhs: String) -> Bool {
        dateForLabel(lhs) < dateForLabel(rhs)
    }

    private func dateForLabel(_ label: String) -> Date {
        if label == "Aujourd'hui" { return Calendar.current.startOfDay(for: .now) }
        if label == "Demain" {
            return Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now)) ?? .now
        }
        return GestionFormatters.mediumFrenchDate.date(from: label) ?? .distantFuture
    }
}
