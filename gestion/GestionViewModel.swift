import Observation
import SwiftData
import SwiftUI

@Observable
final class GestionViewModel {
    var selectedTab: WorkspaceTab = .dashboard
    var searchText = ""
    var activeSheet: EditorSheet?
    var deletionTarget: DeletionTarget?
    var quoteToExport: QuoteRecord?
    var exportDocument: PDFFileDocument?
    var isShowingExporter = false

    private let seedKey = "hasSeededSampleData"

    var hasSeededSampleData: Bool {
        get { UserDefaults.standard.bool(forKey: seedKey) }
        set { UserDefaults.standard.set(newValue, forKey: seedKey) }
    }

    func filteredClients(from clients: [ClientRecord]) -> [ClientRecord] {
        guard !searchText.isEmpty else { return clients }
        return clients.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
            || $0.city.localizedCaseInsensitiveContains(searchText)
            || $0.phone.localizedCaseInsensitiveContains(searchText)
        }
    }

    func filteredInterventions(from interventions: [InterventionRecord]) -> [InterventionRecord] {
        guard !searchText.isEmpty else { return interventions }
        return interventions.filter {
            $0.clientName.localizedCaseInsensitiveContains(searchText)
            || $0.location.localizedCaseInsensitiveContains(searchText)
            || $0.kind.localizedCaseInsensitiveContains(searchText)
        }
    }

    func filteredQuotes(from quotes: [QuoteRecord]) -> [QuoteRecord] {
        guard !searchText.isEmpty else { return quotes }
        return quotes.filter {
            $0.reference.localizedCaseInsensitiveContains(searchText)
            || $0.clientName.localizedCaseInsensitiveContains(searchText)
        }
    }

    func filteredInventory(from inventory: [InventoryItemRecord]) -> [InventoryItemRecord] {
        guard !searchText.isEmpty else { return inventory }
        return inventory.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
            || $0.sku.localizedCaseInsensitiveContains(searchText)
            || $0.supplier.localizedCaseInsensitiveContains(searchText)
        }
    }

    func metrics(quotes: [QuoteRecord], interventions: [InterventionRecord], inventory: [InventoryItemRecord]) -> [DashboardMetric] {
        [
            DashboardMetric(
                title: "CA du mois",
                value: quotes.filter { $0.status == QuoteStatus.sent.rawValue }.map(\.amount).reduce(0, +).formattedEuro,
                detail: "\(quotes.filter { $0.status == QuoteStatus.sent.rawValue }.count) factures envoyées",
                icon: "eurosign.circle.fill",
                color: .green
            ),
            DashboardMetric(
                title: "Factures à relancer",
                value: "\(quotes.filter { $0.status == QuoteStatus.late.rawValue }.count)",
                detail: quotes.filter { $0.status == QuoteStatus.late.rawValue }.map(\.amount).reduce(0, +).formattedEuro,
                icon: "exclamationmark.circle.fill",
                color: .orange
            ),
            DashboardMetric(
                title: "Interventions planifiées",
                value: "\(interventions.count)",
                detail: "\(interventions.filter { $0.priority == PriorityLevel.urgent.rawValue }.count) urgentes",
                icon: "calendar.circle.fill",
                color: .blue
            ),
            DashboardMetric(
                title: "Matériel critique",
                value: "\(inventory.filter { $0.stockLevel == StockLevel.critical.rawValue }.count)",
                detail: "\(inventory.filter { $0.stockLevel == StockLevel.warning.rawValue }.count) références à surveiller",
                icon: "shippingbox.circle.fill",
                color: .red
            )
        ]
    }

    func upcomingInterventions(from interventions: [InterventionRecord]) -> [InterventionRecord] {
        interventions.sorted { $0.sortDate < $1.sortDate }
    }

    func groupedInterventions(from interventions: [InterventionRecord]) -> [(date: String, items: [InterventionRecord])] {
        Dictionary(grouping: interventions, by: \.dateLabel)
            .keys
            .sorted(by: daySort)
            .map { key in
                let items = interventions
                    .filter { $0.dateLabel == key }
                    .sorted { $0.timeSlot < $1.timeSlot }
                return (key, items)
            }
    }

    func todaysInterventionCount(from interventions: [InterventionRecord]) -> Int {
        interventions.filter { Calendar.current.isDateInToday($0.sortDate) }.count
    }

    func pendingQuoteCount(from quotes: [QuoteRecord]) -> Int {
        quotes.filter { $0.status == QuoteStatus.pending.rawValue }.count
    }

    func criticalStockCount(from inventory: [InventoryItemRecord]) -> Int {
        inventory.filter { $0.stockLevel == StockLevel.critical.rawValue }.count
    }

    func presentNewForm(for tab: WorkspaceTab) {
        switch tab {
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
            if let object = fetchModel(ClientRecord.self, id: id, in: modelContext) { modelContext.delete(object) }
        case .intervention(let id):
            if let object = fetchModel(InterventionRecord.self, id: id, in: modelContext) { modelContext.delete(object) }
        case .quote(let id):
            if let object = fetchModel(QuoteRecord.self, id: id, in: modelContext) { modelContext.delete(object) }
        case .inventory(let id):
            if let object = fetchModel(InventoryItemRecord.self, id: id, in: modelContext) { modelContext.delete(object) }
        }
        try? modelContext.save()
    }

    func saveClient(_ draft: ClientDraft, in modelContext: ModelContext) {
        if let id = draft.id, let client = fetchModel(ClientRecord.self, id: id, in: modelContext) {
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
        if let id = draft.id, let intervention = fetchModel(InterventionRecord.self, id: id, in: modelContext) {
            intervention.clientName = draft.clientName
            intervention.location = draft.location
            intervention.kind = draft.kind
            intervention.date = draft.scheduledDate
            intervention.timeSlot = draft.timeSlot
            intervention.priority = draft.priority.rawValue
            intervention.progress = draft.progress
            intervention.notes = draft.notes
            intervention.sortDate = draft.sortDate
        } else {
            modelContext.insert(draft.makeIntervention())
        }
        try? modelContext.save()
    }

    func saveQuote(_ draft: QuoteDraft, in modelContext: ModelContext) {
        if let id = draft.id, let quote = fetchModel(QuoteRecord.self, id: id, in: modelContext) {
            quote.reference = draft.reference
            quote.clientName = draft.clientName
            quote.amount = draft.amount
            quote.dueDate = draft.dueDate
            quote.status = draft.status.rawValue
            quote.summary = draft.summary
        } else {
            modelContext.insert(draft.makeQuote())
        }
        try? modelContext.save()
    }

    func saveInventory(_ draft: InventoryDraft, in modelContext: ModelContext) {
        if let id = draft.id, let item = fetchModel(InventoryItemRecord.self, id: id, in: modelContext) {
            item.name = draft.name
            item.sku = draft.sku
            item.quantity = draft.quantity
            item.stockLevel = draft.inferredLevel.rawValue
            item.supplier = draft.supplier
            item.storageLocation = draft.storageLocation
            item.minimumQuantity = draft.minimumQuantity
        } else {
            modelContext.insert(draft.makeItem())
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

        SampleData.clients.forEach { modelContext.insert($0) }
        SampleData.interventions.forEach { modelContext.insert($0) }
        SampleData.quotes.forEach { modelContext.insert($0) }
        SampleData.inventory.forEach { modelContext.insert($0) }
        try? modelContext.save()
        hasSeededSampleData = true
    }

    private func fetchModel<T: PersistentModel>(_ type: T.Type, id: PersistentIdentifier, in modelContext: ModelContext) -> T? {
        let descriptor = FetchDescriptor<T>()
        let items = (try? modelContext.fetch(descriptor)) ?? []
        return items.first { $0.persistentModelID == id }
    }

    private func daySort(lhs: String, rhs: String) -> Bool {
        dateForLabel(lhs) < dateForLabel(rhs)
    }

    private func dateForLabel(_ label: String) -> Date {
        if label == "Aujourd'hui" { return Calendar.current.startOfDay(for: .now) }
        if label == "Demain" {
            return Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now)) ?? .now
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .medium
        return formatter.date(from: label) ?? .distantFuture
    }
}
