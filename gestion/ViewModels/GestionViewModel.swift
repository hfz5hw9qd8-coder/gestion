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
    var quoteToExport: Quote?
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

    // MARK: - View state

    func makeViewState(
        clients: [Client],
        interventions: [Intervention],
        quotes: [Quote],
        inventory: [InventoryItem]
    ) -> GestionViewState {

        let filteredClients       = filterClients(clients)
        let filteredInterventions = filterInterventions(interventions)
        let filteredQuotes        = filterQuotes(quotes)
        let filteredInventory     = filterInventory(inventory)
        let sortedInterventions   = interventions.sorted { $0.sortDate < $1.sortDate }
        let grouped               = groupInterventions(filteredInterventions)

        // — Chiffres devis/factures —
        var monthlyRevenue    = 0.0
        var outstandingBalance = 0.0
        var pendingCount = 0, lateCount = 0, paidCount = 0
        for quote in quotes {
            if quote.documentTypeValue == .invoice {
                monthlyRevenue     += quote.amountPaid
                outstandingBalance += quote.balanceDue
            }
            switch quote.statusValue {
            case .pending: pendingCount += 1
            case .late:    lateCount    += 1
            case .paid:    paidCount    += 1
            case .sent:    break
            }
        }

        // — Chiffres interventions —
        var urgentCount = 0, todayCount = 0, completedCount = 0, stockCostToday = 0.0
        for i in interventions {
            if i.priorityValue == .urgent   { urgentCount    += 1 }
            if i.statusValue   == .completed { completedCount += 1 }
            if Calendar.current.isDateInToday(i.sortDate) {
                todayCount    += 1
                stockCostToday += i.usedItemsCost
            }
        }

        // — Chiffres stock (✅ dead code allocatedUnits supprimé) —
        var criticalCount = 0, warningCount = 0, inventoryValue = 0.0
        for item in inventory {
            switch item.levelValue {
            case .critical: criticalCount += 1
            case .warning:  warningCount  += 1
            case .normal:   break
            }
            inventoryValue += item.currentValue
        }

        let metrics = [
            DashboardMetric(title: "Encaissements suivis",  value: monthlyRevenue.formattedEuro,     detail: "\(paidCount) factures réglées",                      icon: "eurosign.circle.fill",                    color: .green),
            DashboardMetric(title: "Reste à encaisser",     value: outstandingBalance.formattedEuro,  detail: "\(lateCount) relances, \(pendingCount) validations", icon: "creditcard.trianglebadge.exclamationmark", color: .orange),
            DashboardMetric(title: "Planning",              value: "\(interventions.count)",          detail: "\(completedCount) terminées, \(urgentCount) urgentes", icon: "calendar.circle.fill",                    color: .blue),
            DashboardMetric(title: "Stock valorisé",        value: inventoryValue.formattedEuro,      detail: "\(criticalCount) références critiques",               icon: "shippingbox.circle.fill",                 color: .red)
        ]

        let highlights = [
            DashboardHighlight(title: "Matériel engagé aujourd'hui", detail: stockCostToday.formattedEuro,                       icon: "shippingbox.and.arrow.backward", color: .orange),
            DashboardHighlight(title: "Planning semaine",            detail: "\(interventionsThisWeek(interventions)) interventions", icon: "calendar.badge.clock",           color: .blue),
            DashboardHighlight(title: "Surveillance stock",          detail: "\(warningCount) références à suivre",               icon: "exclamationmark.triangle",       color: .yellow)
        ]

        return GestionViewState(
            filteredClients: filteredClients,
            filteredInterventions: filteredInterventions,
            filteredQuotes: filteredQuotes,
            filteredInventory: filteredInventory,
            metrics: metrics,
            highlights: highlights,
            upcomingInterventions: sortedInterventions,
            groupedInterventions: grouped,
            todaysInterventionCount: todayCount,
            pendingQuoteCount: pendingCount,
            criticalStockCount: criticalCount,
            monthlyRevenue: monthlyRevenue,
            outstandingBalance: outstandingBalance
        )
    }

    // MARK: - Options

    func clientOptions(from clients: [Client]) -> [ClientOption] {
        clients.sorted { $0.name < $1.name }.map { ClientOption(id: $0.persistentModelID, name: $0.name) }
    }

    func inventoryOptions(from inventory: [InventoryItem]) -> [InventoryOption] {
        inventory.sorted { $0.name < $1.name }.map {
            InventoryOption(id: $0.persistentModelID, name: $0.name, sku: $0.sku,
                            availableQuantity: $0.availableQuantity, unitCost: $0.unitCost)
        }
    }

    // MARK: - Navigation

    func presentNewForm() {
        switch selectedTab {
        case .dashboard, .planning: break
        case .clients:       activeSheet = .client(ClientDraft())
        case .interventions: activeSheet = .intervention(InterventionDraft())
        case .quotes:        activeSheet = .quote(QuoteDraft())
        case .inventory:     activeSheet = .inventory(InventoryDraft())
        }
    }

    // MARK: - CRUD

    func delete(_ target: DeletionTarget, in ctx: ModelContext) {
        switch target {
        case .client(let id):       (ctx.model(for: id) as? Client).map        { ctx.delete($0) }
        case .intervention(let id): (ctx.model(for: id) as? Intervention).map   { ctx.delete($0) }
        case .quote(let id):        (ctx.model(for: id) as? Quote).map          { ctx.delete($0) }
        case .inventory(let id):    (ctx.model(for: id) as? InventoryItem).map  { ctx.delete($0) }
        }
        try? ctx.save()
    }

    func saveClient(_ draft: ClientDraft, in ctx: ModelContext) {
        if let id = draft.id, let c = ctx.model(for: id) as? Client {
            c.name = draft.name; c.city = draft.city; c.note = draft.note
            c.status = draft.status.rawValue; c.phone = draft.phone
            c.email = draft.email; c.address = draft.address
        } else {
            ctx.insert(draft.makeClient())
        }
        try? ctx.save()
    }

    func saveIntervention(_ draft: InterventionDraft, in ctx: ModelContext) {
        let client = draft.clientID.flatMap { ctx.model(for: $0) as? Client }

        let record: Intervention
        if let id = draft.id, let existing = ctx.model(for: id) as? Intervention {
            record = existing
            record.stockUsages.forEach { ctx.delete($0) }
        } else {
            record = Intervention(
                clientName: draft.clientName, location: draft.location,
                kind: draft.kind, date: draft.scheduledDate,
                timeSlot: draft.timeSlot, priority: draft.priority.rawValue,
                progress: draft.progress, notes: draft.notes,
                executionStatus: draft.executionStatus.rawValue, client: client
            )
            ctx.insert(record)
        }

        // ✅ date et sortDate mis à jour ensemble pour éviter l'incohérence
        record.client          = client
        record.clientName      = draft.clientName
        record.location        = draft.location
        record.kind            = draft.kind
        record.date            = draft.scheduledDate
        record.sortDate        = draft.scheduledDate   // ✅ synchronisé explicitement
        record.timeSlot        = draft.timeSlot
        record.priority        = draft.priority.rawValue
        record.executionStatus = draft.executionStatus.rawValue
        record.progress        = draft.progress
        record.notes           = draft.notes
        record.stockUsages     = draft.stockUsages.compactMap { usage in
            guard usage.quantityUsed > 0 else { return nil }
            let inv = usage.inventoryItemID.flatMap { ctx.model(for: $0) as? InventoryItem }
            return StockUsage(
                inventoryItemName: inv?.name ?? usage.inventoryItemName,
                quantityUsed: usage.quantityUsed,
                unitCost: inv?.unitCost ?? usage.unitCost,
                intervention: record, inventoryItem: inv
            )
        }
        try? ctx.save()
    }

    func saveQuote(_ draft: QuoteDraft, in ctx: ModelContext) {
        let client = draft.clientID.flatMap { ctx.model(for: $0) as? Client }

        let quote: Quote
        if let id = draft.id, let existing = ctx.model(for: id) as? Quote {
            quote = existing
            quote.lines.forEach    { ctx.delete($0) }
            quote.payments.forEach { ctx.delete($0) }
        } else {
            quote = Quote(
                reference: draft.reference, clientName: draft.clientName,
                dueDate: draft.dueDate, status: draft.status.rawValue,
                summary: draft.summary, documentType: draft.documentType.rawValue,
                depositRate: draft.depositRate, client: client
            )
            ctx.insert(quote)
        }

        quote.client = client; quote.reference = draft.reference
        quote.clientName = draft.clientName; quote.dueDate = draft.dueDate
        quote.status = draft.status.rawValue; quote.summary = draft.summary
        quote.documentType = draft.documentType.rawValue; quote.depositRate = draft.depositRate

        quote.lines = draft.lines.compactMap { line in
            guard !line.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return QuoteLine(title: line.title, lineDescription: line.lineDescription,
                                   quantity: line.quantity, unitPrice: line.unitPrice,
                                   taxRate: line.taxRate, quote: quote)
        }
        quote.payments = draft.payments.compactMap { payment in
            guard payment.amount > 0 else { return nil }
            return Payment(paidAt: payment.paidAt, amount: payment.amount,
                                 method: payment.method.rawValue, note: payment.note, quote: quote)
        }
        // Auto-marquer comme réglé si balance à zéro
        if quote.balanceDue == 0, quote.totalAmount > 0 {
            quote.status = QuoteStatus.paid.rawValue
        }
        try? ctx.save()
    }

    func saveInventory(_ draft: InventoryDraft, in ctx: ModelContext) {
        let item: InventoryItem
        if let id = draft.id, let existing = ctx.model(for: id) as? InventoryItem {
            item = existing
            item.movements.forEach { ctx.delete($0) }
        } else {
            item = draft.makeItem()
            ctx.insert(item)
        }

        item.name = draft.name; item.sku = draft.sku; item.quantity = draft.quantity
        item.stockLevel = draft.inferredLevel.rawValue; item.supplier = draft.supplier
        item.storageLocation = draft.storageLocation; item.minimumQuantity = draft.minimumQuantity
        item.unitCost = draft.unitCost
        item.movements = draft.movements.compactMap { m in
            guard m.quantityDelta != 0 else { return nil }
            return InventoryMovement(movedAt: m.movedAt, quantityDelta: m.quantityDelta,
                                           type: m.type.rawValue, note: m.note, inventoryItem: item)
        }
        try? ctx.save()
    }

    // MARK: - PDF

    func exportPDF(for quote: Quote) {
        exportDocument = PDFFileDocument(data: PDFRenderer.renderQuotePDF(for: quote))
        quoteToExport  = quote
        isShowingExporter = true
    }

    func clearExportState() {
        quoteToExport  = nil
        exportDocument = nil
    }

    // MARK: - Seed

    func seedDataIfNeeded(
        clients: [Client], interventions: [Intervention],
        quotes: [Quote], inventory: [InventoryItem],
        in ctx: ModelContext
    ) {
        guard !hasSeededSampleData else { return }
        guard clients.isEmpty, interventions.isEmpty, quotes.isEmpty, inventory.isEmpty else {
            hasSeededSampleData = true; return
        }
        SampleData.populate(in: ctx)
        try? ctx.save()
        hasSeededSampleData = true
    }

    // MARK: - Filtres

    private func filterClients(_ clients: [Client]) -> [Client] {
        guard !searchText.isEmpty else { return clients }
        return clients.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
            || $0.city.localizedCaseInsensitiveContains(searchText)
            || $0.phone.localizedCaseInsensitiveContains(searchText)
            || $0.quotes.contains { $0.reference.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private func filterInterventions(_ interventions: [Intervention]) -> [Intervention] {
        let base = planningFiltered(interventions)
        guard !searchText.isEmpty else { return base }
        return base.filter {
            $0.clientName.localizedCaseInsensitiveContains(searchText)
            || $0.location.localizedCaseInsensitiveContains(searchText)
            || $0.kind.localizedCaseInsensitiveContains(searchText)
            || $0.stockUsages.contains { $0.inventoryItemName.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private func filterQuotes(_ quotes: [Quote]) -> [Quote] {
        guard !searchText.isEmpty else { return quotes }
        return quotes.filter {
            $0.reference.localizedCaseInsensitiveContains(searchText)
            || $0.clientName.localizedCaseInsensitiveContains(searchText)
            || $0.lines.contains { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private func filterInventory(_ inventory: [InventoryItem]) -> [InventoryItem] {
        guard !searchText.isEmpty else { return inventory }
        return inventory.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
            || $0.sku.localizedCaseInsensitiveContains(searchText)
            || $0.supplier.localizedCaseInsensitiveContains(searchText)
            || $0.usages.contains { $0.inventoryItemName.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private func planningFiltered(_ interventions: [Intervention]) -> [Intervention] {
        switch planningFilter {
        case .all:       return interventions
        case .week:      return interventions.filter { Calendar.current.isDate($0.sortDate, equalTo: .now, toGranularity: .weekOfYear) }
        case .open:      return interventions.filter { $0.statusValue != .completed }
        case .completed: return interventions.filter { $0.statusValue == .completed }
        }
    }

    private func groupInterventions(_ interventions: [Intervention]) -> [(date: String, items: [Intervention])] {
        let grouped = Dictionary(grouping: interventions) { $0.dateLabel }
        return grouped.keys.sorted(by: daySort).map { key in
            let items = (grouped[key] ?? []).sorted { $0.timeSlot < $1.timeSlot }
            return (key, items)
        }
    }

    private func interventionsThisWeek(_ interventions: [Intervention]) -> Int {
        interventions.filter { Calendar.current.isDate($0.sortDate, equalTo: .now, toGranularity: .weekOfYear) }.count
    }

    private func daySort(lhs: String, rhs: String) -> Bool { dateForLabel(lhs) < dateForLabel(rhs) }

    private func dateForLabel(_ label: String) -> Date {
        if label == "Aujourd'hui" { return Calendar.current.startOfDay(for: .now) }
        if label == "Demain"      { return Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now)) ?? .now }
        return GestionFormatters.mediumFrenchDate.date(from: label) ?? .distantFuture
    }
}
