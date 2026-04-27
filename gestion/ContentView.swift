import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClientRecord.name) private var clients: [ClientRecord]
    @Query(sort: \InterventionRecord.sortDate) private var interventions: [InterventionRecord]
    @Query(sort: \QuoteRecord.reference, order: .reverse) private var quotes: [QuoteRecord]
    @Query(sort: \InventoryItemRecord.name) private var inventory: [InventoryItemRecord]

    @AppStorage("hasSeededSampleData") private var hasSeededSampleData = false

    @State private var selectedTab: WorkspaceTab = .dashboard
    @State private var searchText = ""
    @State private var activeSheet: EditorSheet?
    @State private var deletionTarget: DeletionTarget?
    @State private var quoteToExport: QuoteRecord?
    @State private var exportDocument: PDFFileDocument?
    @State private var isShowingExporter = false

    private var filteredClients: [ClientRecord] {
        guard !searchText.isEmpty else { return clients }
        return clients.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
            || $0.city.localizedCaseInsensitiveContains(searchText)
            || $0.phone.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredInterventions: [InterventionRecord] {
        guard !searchText.isEmpty else { return interventions }
        return interventions.filter {
            $0.clientName.localizedCaseInsensitiveContains(searchText)
            || $0.location.localizedCaseInsensitiveContains(searchText)
            || $0.kind.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredQuotes: [QuoteRecord] {
        guard !searchText.isEmpty else { return quotes }
        return quotes.filter {
            $0.reference.localizedCaseInsensitiveContains(searchText)
            || $0.clientName.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredInventory: [InventoryItemRecord] {
        guard !searchText.isEmpty else { return inventory }
        return inventory.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
            || $0.sku.localizedCaseInsensitiveContains(searchText)
            || $0.supplier.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var metrics: [DashboardMetric] {
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

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.96, blue: 0.98),
                        Color(red: 0.87, green: 0.91, blue: 0.96)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        heroSection
                        tabSelector

                        switch selectedTab {
                        case .dashboard:
                            dashboardSection
                        case .planning:
                            planningSection
                        case .clients:
                            clientsSection
                        case .interventions:
                            interventionsSection
                        case .quotes:
                            quotesSection
                        case .inventory:
                            inventorySection
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Gestion Électricien")
            .searchable(text: $searchText, prompt: "Client, chantier, référence")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if selectedTab != .dashboard && selectedTab != .planning {
                        Button {
                            presentNewForm(for: selectedTab)
                        } label: {
                            Label("Ajouter", systemImage: "plus")
                        }
                    }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                editorSheetContent(for: sheet)
            }
            .fileExporter(
                isPresented: $isShowingExporter,
                document: exportDocument,
                contentType: .pdf,
                defaultFilename: quoteToExport?.reference.replacingOccurrences(of: "/", with: "-") ?? "document"
            ) { _ in
                quoteToExport = nil
                exportDocument = nil
            }
            .alert(item: $deletionTarget) { target in
                Alert(
                    title: Text("Supprimer \(target.kind)?"),
                    message: Text("Cette action est définitive."),
                    primaryButton: .destructive(Text("Supprimer")) {
                        delete(target)
                    },
                    secondaryButton: .cancel()
                )
            }
            .task {
                seedDataIfNeeded()
            }
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Pilotage de l'activité")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)

                    Text("Planning, facturation, clients et stock dans la même application.")
                        .font(.system(size: 30, weight: .bold, design: .rounded))

                    Text("Les données sont stockées avec SwiftData et les devis/factures peuvent être exportés en PDF.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 8) {
                    Label("\(todaysInterventionCount) interventions aujourd'hui", systemImage: "bolt.badge.clock")
                    Label("\(pendingQuoteCount) devis en attente", systemImage: "doc.text.magnifyingglass")
                    Label("\(criticalStockCount) alertes stock", systemImage: "shippingbox.circle")
                }
                .font(.footnote.weight(.semibold))
                .padding(14)
                .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.99, green: 0.71, blue: 0.17),
                            Color(red: 0.97, green: 0.50, blue: 0.09)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 72))
                .foregroundStyle(.white.opacity(0.16))
                .padding(20)
        }
        .shadow(color: .black.opacity(0.08), radius: 18, y: 12)
    }

    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(WorkspaceTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: tab.icon)
                            Text(tab.title)
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selectedTab == tab ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(selectedTab == tab ? Color.black : Color.white.opacity(0.75))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var dashboardSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Vue d'ensemble")
                .font(.title3.bold())

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(metrics) { metric in
                    MetricCard(metric: metric)
                }
            }

            contentPanel(title: "Planning du jour", systemImage: "calendar") {
                VStack(spacing: 12) {
                    ForEach(upcomingInterventions.prefix(3)) { intervention in
                        NavigationLink {
                            InterventionDetailView(intervention: intervention)
                        } label: {
                            scheduleRow(for: intervention)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var planningSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(title: "Planning", subtitle: "\(filteredInterventions.count) interventions")

            contentPanel(title: "Agenda des chantiers", systemImage: "calendar.badge.clock") {
                VStack(spacing: 18) {
                    ForEach(groupedInterventions, id: \.date) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(group.date)
                                .font(.headline)
                            ForEach(group.items) { intervention in
                                NavigationLink {
                                    InterventionDetailView(intervention: intervention)
                                } label: {
                                    HStack(spacing: 14) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(intervention.timeSlot)
                                                .font(.headline)
                                            Text(intervention.clientName)
                                                .font(.subheadline.weight(.semibold))
                                            Text(intervention.kind)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 6) {
                                            StatusBadge(title: intervention.priorityValue.label, color: intervention.priorityValue.color)
                                            Text(intervention.location)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(14)
                                    .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }

    private var clientsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(title: "Fichier clients", subtitle: "\(clients.count) fiches")

            contentPanel(title: "Clients actifs", systemImage: "person.2") {
                VStack(spacing: 12) {
                    ForEach(filteredClients) { client in
                        NavigationLink {
                            ClientDetailView(client: client)
                        } label: {
                            cardRow {
                                HStack(alignment: .top, spacing: 14) {
                                    Circle()
                                        .fill(client.statusValue.color.opacity(0.18))
                                        .frame(width: 46, height: 46)
                                        .overlay {
                                            Image(systemName: "person.fill")
                                                .foregroundStyle(client.statusValue.color)
                                        }

                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(alignment: .top) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(client.name)
                                                    .font(.headline)
                                                Text(client.city)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            StatusBadge(title: client.statusValue.label, color: client.statusValue.color)
                                        }

                                        Text(client.note)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)

                                        HStack {
                                            Label(client.phone, systemImage: "phone")
                                            Spacer()
                                            Label(client.email, systemImage: "envelope")
                                        }
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                    }
                                }
                            } menu: {
                                rowMenu(
                                    editAction: { activeSheet = .client(ClientDraft(client: client)) },
                                    deleteAction: { deletionTarget = .client(client.persistentModelID) }
                                )
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var interventionsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(title: "Interventions", subtitle: "\(interventions.count) dossiers")

            contentPanel(title: "Chantiers et dépannages", systemImage: "bolt.circle") {
                VStack(spacing: 12) {
                    ForEach(filteredInterventions) { intervention in
                        NavigationLink {
                            InterventionDetailView(intervention: intervention)
                        } label: {
                            cardRow {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(intervention.clientName)
                                                .font(.headline)
                                            Text(intervention.location)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        StatusBadge(title: intervention.priorityValue.label, color: intervention.priorityValue.color)
                                    }

                                    HStack {
                                        Label(intervention.kind, systemImage: "wrench.and.screwdriver")
                                        Spacer()
                                        Label(intervention.timeSlot, systemImage: "clock")
                                    }
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(.secondary)

                                    Text(intervention.dateLabel)
                                        .font(.footnote.weight(.semibold))

                                    ProgressView(value: intervention.progress)
                                        .tint(intervention.priorityValue.color)
                                }
                            } menu: {
                                rowMenu(
                                    editAction: { activeSheet = .intervention(InterventionDraft(intervention: intervention)) },
                                    deleteAction: { deletionTarget = .intervention(intervention.persistentModelID) }
                                )
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var quotesSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(title: "Devis et factures", subtitle: "\(quotes.count) documents")

            contentPanel(title: "Suivi commercial", systemImage: "doc.plaintext") {
                VStack(spacing: 12) {
                    ForEach(filteredQuotes) { quote in
                        NavigationLink {
                            QuoteDetailView(quote: quote) {
                                exportPDF(for: quote)
                            }
                        } label: {
                            cardRow {
                                HStack(alignment: .top, spacing: 14) {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(quote.statusValue.color.opacity(0.16))
                                        .frame(width: 52, height: 52)
                                        .overlay {
                                            Image(systemName: quote.statusValue.icon)
                                                .foregroundStyle(quote.statusValue.color)
                                        }

                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(quote.reference)
                                                .font(.headline)
                                            Spacer()
                                            Text(quote.formattedAmount)
                                                .font(.headline)
                                        }

                                        Text(quote.clientName)
                                            .foregroundStyle(.secondary)

                                        HStack {
                                            StatusBadge(title: quote.statusValue.label, color: quote.statusValue.color)
                                            Spacer()
                                            Text("Échéance \(quote.dueDate)")
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            } menu: {
                                Button("Exporter PDF", systemImage: "document.badge.gearshape") {
                                    exportPDF(for: quote)
                                }
                                Button("Modifier", systemImage: "pencil") {
                                    activeSheet = .quote(QuoteDraft(quote: quote))
                                }
                                Button("Supprimer", systemImage: "trash", role: .destructive) {
                                    deletionTarget = .quote(quote.persistentModelID)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var inventorySection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(title: "Stock matériel", subtitle: "\(inventory.count) références")

            contentPanel(title: "Réapprovisionnement", systemImage: "shippingbox") {
                VStack(spacing: 12) {
                    ForEach(filteredInventory) { item in
                        NavigationLink {
                            InventoryDetailView(item: item)
                        } label: {
                            cardRow {
                                HStack(spacing: 14) {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(item.levelValue.color.opacity(0.18))
                                        .frame(width: 48, height: 48)
                                        .overlay {
                                            Image(systemName: "cable.connector")
                                                .foregroundStyle(item.levelValue.color)
                                        }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.name)
                                            .font(.headline)
                                        Text("Réf. \(item.sku)")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                        Text(item.supplier)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("\(item.quantity) unités")
                                            .font(.headline)
                                        StatusBadge(title: item.levelValue.label, color: item.levelValue.color)
                                    }
                                }
                            } menu: {
                                rowMenu(
                                    editAction: { activeSheet = .inventory(InventoryDraft(item: item)) },
                                    deleteAction: { deletionTarget = .inventory(item.persistentModelID) }
                                )
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var upcomingInterventions: [InterventionRecord] {
        interventions.sorted { $0.sortDate < $1.sortDate }
    }

    private var groupedInterventions: [(date: String, items: [InterventionRecord])] {
        Dictionary(grouping: filteredInterventions, by: \.dateLabel)
            .keys
            .sorted(by: daySort)
            .map { key in
                let items = filteredInterventions
                    .filter { $0.dateLabel == key }
                    .sorted { $0.timeSlot < $1.timeSlot }
                return (key, items)
            }
    }

    private var todaysInterventionCount: Int {
        interventions.filter { Calendar.current.isDateInToday($0.sortDate) }.count
    }

    private var pendingQuoteCount: Int {
        quotes.filter { $0.status == QuoteStatus.pending.rawValue }.count
    }

    private var criticalStockCount: Int {
        inventory.filter { $0.stockLevel == StockLevel.critical.rawValue }.count
    }

    private func scheduleRow(for intervention: InterventionRecord) -> some View {
        HStack(spacing: 14) {
            VStack {
                Text(intervention.timeSlot.components(separatedBy: " ").first ?? intervention.timeSlot)
                    .font(.headline)
                Text(intervention.shortDateLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 72, height: 58)
            .background(Color.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(intervention.clientName)
                    .font(.headline)
                Text("\(intervention.kind) • \(intervention.location)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            StatusBadge(title: intervention.priorityValue.label, color: intervention.priorityValue.color)
        }
        .padding(14)
        .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func contentPanel<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: systemImage)
                .font(.headline)

            content()
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        HStack {
            Text(title)
                .font(.title3.bold())
            Spacer()
            Text(subtitle)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func cardRow<Content: View, MenuContent: View>(
        @ViewBuilder _ content: () -> Content,
        @ViewBuilder menu: () -> MenuContent
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            content()
            Menu(content: menu) {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func rowMenu(editAction: @escaping () -> Void, deleteAction: @escaping () -> Void) -> some View {
        Button("Modifier", systemImage: "pencil", action: editAction)
        Button("Supprimer", systemImage: "trash", role: .destructive, action: deleteAction)
    }

    private func presentNewForm(for tab: WorkspaceTab) {
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

    private func delete(_ target: DeletionTarget) {
        switch target {
        case .client(let id):
            if let object = fetchModel(ClientRecord.self, id: id) { modelContext.delete(object) }
        case .intervention(let id):
            if let object = fetchModel(InterventionRecord.self, id: id) { modelContext.delete(object) }
        case .quote(let id):
            if let object = fetchModel(QuoteRecord.self, id: id) { modelContext.delete(object) }
        case .inventory(let id):
            if let object = fetchModel(InventoryItemRecord.self, id: id) { modelContext.delete(object) }
        }
        try? modelContext.save()
    }

    private func fetchModel<T: PersistentModel>(_ type: T.Type, id: PersistentIdentifier) -> T? {
        let descriptor = FetchDescriptor<T>()
        let items = (try? modelContext.fetch(descriptor)) ?? []
        return items.first { $0.persistentModelID == id }
    }

    @ViewBuilder
    private func editorSheetContent(for sheet: EditorSheet) -> some View {
        switch sheet {
        case .client(let draft):
            ClientFormView(draft: draft) { updatedDraft in
                saveClient(updatedDraft)
            }
        case .intervention(let draft):
            InterventionFormView(draft: draft) { updatedDraft in
                saveIntervention(updatedDraft)
            }
        case .quote(let draft):
            QuoteFormView(draft: draft) { updatedDraft in
                saveQuote(updatedDraft)
            }
        case .inventory(let draft):
            InventoryFormView(draft: draft) { updatedDraft in
                saveInventory(updatedDraft)
            }
        }
    }

    private func saveClient(_ draft: ClientDraft) {
        if let id = draft.id, let client = fetchModel(ClientRecord.self, id: id) {
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

    private func saveIntervention(_ draft: InterventionDraft) {
        if let id = draft.id, let intervention = fetchModel(InterventionRecord.self, id: id) {
            intervention.clientName = draft.clientName
            intervention.location = draft.location
            intervention.kind = draft.kind
            intervention.date = draft.date
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

    private func saveQuote(_ draft: QuoteDraft) {
        if let id = draft.id, let quote = fetchModel(QuoteRecord.self, id: id) {
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

    private func saveInventory(_ draft: InventoryDraft) {
        if let id = draft.id, let item = fetchModel(InventoryItemRecord.self, id: id) {
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

    private func exportPDF(for quote: QuoteRecord) {
        let data = PDFRenderer.renderQuotePDF(for: quote)
        exportDocument = PDFFileDocument(data: data)
        quoteToExport = quote
        isShowingExporter = true
    }

    private func daySort(lhs: String, rhs: String) -> Bool {
        dateForLabel(lhs) < dateForLabel(rhs)
    }

    private func dateForLabel(_ label: String) -> Date {
        if label == "Aujourd'hui" { return Calendar.current.startOfDay(for: .now) }
        if label == "Demain" { return Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now)) ?? .now }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateStyle = .medium
        return formatter.date(from: label) ?? .distantFuture
    }

    private func seedDataIfNeeded() {
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
}

private struct MetricCard: View {
    let metric: DashboardMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: metric.icon)
                .font(.title3)
                .foregroundStyle(metric.color)

            Text(metric.value)
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text(metric.title)
                .font(.subheadline.weight(.semibold))

            Text(metric.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct StatusBadge: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.12), in: Capsule())
    }
}

private struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

private struct ClientDetailView: View {
    let client: ClientRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DetailHero(title: client.name, subtitle: client.city, color: client.statusValue.color, systemImage: "person.2.fill")
                DetailSection(title: "Coordonnées") {
                    InfoRow(label: "Téléphone", value: client.phone)
                    InfoRow(label: "Email", value: client.email)
                    InfoRow(label: "Adresse", value: client.address)
                }
                DetailSection(title: "Suivi") {
                    InfoRow(label: "Statut", value: client.statusValue.label)
                    InfoRow(label: "Note", value: client.note)
                }
            }
            .padding(20)
        }
        .navigationTitle("Fiche client")
    }
}

private struct InterventionDetailView: View {
    let intervention: InterventionRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DetailHero(title: intervention.clientName, subtitle: intervention.kind, color: intervention.priorityValue.color, systemImage: "bolt.fill")
                DetailSection(title: "Organisation") {
                    InfoRow(label: "Date", value: intervention.dateLabel)
                    InfoRow(label: "Créneau", value: intervention.timeSlot)
                    InfoRow(label: "Lieu", value: intervention.location)
                    InfoRow(label: "Priorité", value: intervention.priorityValue.label)
                }
                DetailSection(title: "Avancement") {
                    ProgressView(value: intervention.progress)
                        .tint(intervention.priorityValue.color)
                    InfoRow(label: "Progression", value: "\(Int(intervention.progress * 100)) %")
                    InfoRow(label: "Notes", value: intervention.notes)
                }
            }
            .padding(20)
        }
        .navigationTitle("Intervention")
    }
}

private struct QuoteDetailView: View {
    let quote: QuoteRecord
    let onExportPDF: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DetailHero(title: quote.reference, subtitle: quote.clientName, color: quote.statusValue.color, systemImage: "doc.text.fill")
                DetailSection(title: "Document") {
                    InfoRow(label: "Montant", value: quote.formattedAmount)
                    InfoRow(label: "Échéance", value: quote.dueDate)
                    InfoRow(label: "Statut", value: quote.statusValue.label)
                }
                DetailSection(title: "Description") {
                    Text(quote.summary)
                        .font(.subheadline)
                }
                Button {
                    onExportPDF()
                } label: {
                    Label("Exporter en PDF", systemImage: "document.badge.gearshape")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.black)
            }
            .padding(20)
        }
        .navigationTitle("Devis / Facture")
    }
}

private struct InventoryDetailView: View {
    let item: InventoryItemRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DetailHero(title: item.name, subtitle: item.sku, color: item.levelValue.color, systemImage: "shippingbox.fill")
                DetailSection(title: "Stock") {
                    InfoRow(label: "Quantité", value: "\(item.quantity) unités")
                    InfoRow(label: "Seuil d'alerte", value: "\(item.minimumQuantity) unités")
                    InfoRow(label: "Niveau", value: item.levelValue.label)
                }
                DetailSection(title: "Approvisionnement") {
                    InfoRow(label: "Fournisseur", value: item.supplier)
                    InfoRow(label: "Emplacement", value: item.storageLocation)
                }
            }
            .padding(20)
        }
        .navigationTitle("Matériel")
    }
}

private struct DetailHero: View {
    let title: String
    let subtitle: String
    let color: Color
    let systemImage: String

    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(color.opacity(0.18))
                .frame(width: 72, height: 72)
                .overlay {
                    Image(systemName: systemImage)
                        .font(.title)
                        .foregroundStyle(color)
                }
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title2.bold())
                Text(subtitle)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct ClientFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State var draft: ClientDraft
    let onSave: (ClientDraft) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Client") {
                    TextField("Nom", text: $draft.name)
                    TextField("Ville", text: $draft.city)
                    Picker("Statut", selection: $draft.status) {
                        ForEach(ClientStatus.allCases) { status in
                            Text(status.label).tag(status)
                        }
                    }
                }
                Section("Coordonnées") {
                    TextField("Téléphone", text: $draft.phone)
                    TextField("Email", text: $draft.email)
                    TextField("Adresse", text: $draft.address, axis: .vertical)
                }
                Section("Note") {
                    TextField("Informations complémentaires", text: $draft.note, axis: .vertical)
                }
            }
            .navigationTitle(draft.id == nil ? "Nouveau client" : "Modifier client")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct InterventionFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State var draft: InterventionDraft
    let onSave: (InterventionDraft) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Intervention") {
                    TextField("Client", text: $draft.clientName)
                    TextField("Type d'intervention", text: $draft.kind)
                    TextField("Lieu", text: $draft.location)
                }
                Section("Planification") {
                    DatePicker("Date", selection: $draft.scheduledDate, displayedComponents: .date)
                    TextField("Créneau", text: $draft.timeSlot)
                    Picker("Priorité", selection: $draft.priority) {
                        ForEach(PriorityLevel.allCases) { priority in
                            Text(priority.label).tag(priority)
                        }
                    }
                }
                Section("Suivi") {
                    Slider(value: $draft.progress, in: 0...1)
                    Text("Progression : \(Int(draft.progress * 100)) %")
                    TextField("Notes", text: $draft.notes, axis: .vertical)
                }
            }
            .navigationTitle(draft.id == nil ? "Nouvelle intervention" : "Modifier intervention")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(draft.clientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.kind.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct QuoteFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State var draft: QuoteDraft
    let onSave: (QuoteDraft) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Document") {
                    TextField("Référence", text: $draft.reference)
                    TextField("Client", text: $draft.clientName)
                    TextField("Montant", value: $draft.amount, format: .number)
                    TextField("Échéance", text: $draft.dueDate)
                    Picker("Statut", selection: $draft.status) {
                        ForEach(QuoteStatus.allCases) { status in
                            Text(status.label).tag(status)
                        }
                    }
                }
                Section("Résumé") {
                    TextField("Description", text: $draft.summary, axis: .vertical)
                }
            }
            .navigationTitle(draft.id == nil ? "Nouveau devis" : "Modifier document")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(draft.reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.clientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct InventoryFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State var draft: InventoryDraft
    let onSave: (InventoryDraft) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Article") {
                    TextField("Nom", text: $draft.name)
                    TextField("Référence", text: $draft.sku)
                    TextField("Fournisseur", text: $draft.supplier)
                    TextField("Emplacement", text: $draft.storageLocation)
                }
                Section("Stock") {
                    Stepper("Quantité : \(draft.quantity)", value: $draft.quantity, in: 0...999)
                    Stepper("Seuil d'alerte : \(draft.minimumQuantity)", value: $draft.minimumQuantity, in: 0...999)
                    Picker("Niveau", selection: $draft.level) {
                        ForEach(StockLevel.allCases) { level in
                            Text(level.label).tag(level)
                        }
                    }
                }
            }
            .navigationTitle(draft.id == nil ? "Nouvel article" : "Modifier article")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.sku.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct PDFFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private enum PDFRenderer {
    static func renderQuotePDF(for quote: QuoteRecord) -> Data {
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return Data()
        }

        context.beginPDFPage(nil)

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 26),
            .foregroundColor: NSColor.black
        ]
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.darkGray
        ]
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.black
        ]

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

        ("Entreprise Électricité".NSString).draw(at: CGPoint(x: 48, y: 780), withAttributes: titleAttributes)
        ("Devis / Facture professionnel".NSString).draw(at: CGPoint(x: 48, y: 750), withAttributes: subtitleAttributes)

        let lines = [
            "Référence : \(quote.reference)",
            "Client : \(quote.clientName)",
            "Statut : \(quote.statusValue.label)",
            "Échéance : \(quote.dueDate)",
            "Montant : \(quote.formattedAmount)"
        ]

        for (index, line) in lines.enumerated() {
            (line.NSString).draw(at: CGPoint(x: 48, y: 690 - CGFloat(index * 28)), withAttributes: bodyAttributes)
        }

        let summaryRect = CGRect(x: 48, y: 430, width: 500, height: 160)
        ("Description des travaux :\n\(quote.summary)".NSString).draw(in: summaryRect, withAttributes: bodyAttributes)
        ("Document généré depuis l'application Gestion Électricien.".NSString).draw(at: CGPoint(x: 48, y: 60), withAttributes: subtitleAttributes)

        NSGraphicsContext.restoreGraphicsState()
        context.endPDFPage()
        context.closePDF()
        return data as Data
    }
}

private enum WorkspaceTab: String, CaseIterable, Identifiable {
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

private enum EditorSheet: Identifiable {
    case client(ClientDraft)
    case intervention(InterventionDraft)
    case quote(QuoteDraft)
    case inventory(InventoryDraft)

    var id: String {
        switch self {
        case .client(let draft):
            return "client-\(draft.id?.id.description ?? "new")"
        case .intervention(let draft):
            return "intervention-\(draft.id?.id.description ?? "new")"
        case .quote(let draft):
            return "quote-\(draft.id?.id.description ?? "new")"
        case .inventory(let draft):
            return "inventory-\(draft.id?.id.description ?? "new")"
        }
    }
}

private enum DeletionTarget: Identifiable {
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

private struct DashboardMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let detail: String
    let icon: String
    let color: Color
}

private enum ClientStatus: String, CaseIterable, Identifiable {
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

private enum PriorityLevel: String, CaseIterable, Identifiable {
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

private enum QuoteStatus: String, CaseIterable, Identifiable {
    case pending
    case sent
    case late

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pending: return "À valider"
        case .sent: return "Envoyée"
        case .late: return "Relance"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .orange
        case .sent: return .blue
        case .late: return .red
        }
    }

    var icon: String {
        switch self {
        case .pending: return "doc.badge.clock"
        case .sent: return "paperplane"
        case .late: return "exclamationmark.arrow.trianglehead.counterclockwise"
        }
    }
}

private enum StockLevel: String, CaseIterable, Identifiable {
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

@Model
final class ClientRecord {
    var name: String
    var city: String
    var note: String
    var status: String
    var phone: String
    var email: String
    var address: String

    init(name: String, city: String, note: String, status: String, phone: String, email: String, address: String) {
        self.name = name
        self.city = city
        self.note = note
        self.status = status
        self.phone = phone
        self.email = email
        self.address = address
    }

    var statusValue: ClientStatus {
        ClientStatus(rawValue: status) ?? .active
    }
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

    init(clientName: String, location: String, kind: String, date: Date, timeSlot: String, priority: String, progress: Double, notes: String) {
        self.clientName = clientName
        self.location = location
        self.kind = kind
        self.date = date
        self.timeSlot = timeSlot
        self.priority = priority
        self.progress = progress
        self.notes = notes
        self.sortDate = date
    }

    var priorityValue: PriorityLevel {
        PriorityLevel(rawValue: priority) ?? .normal
    }

    var dateLabel: String {
        if Calendar.current.isDateInToday(date) { return "Aujourd'hui" }
        if Calendar.current.isDateInTomorrow(date) { return "Demain" }
        return date.formatted(.dateTime.day().month(.abbreviated).year())
    }

    var shortDateLabel: String {
        if Calendar.current.isDateInToday(date) { return "Aujourd'hui" }
        if Calendar.current.isDateInTomorrow(date) { return "Demain" }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }
}

@Model
final class QuoteRecord {
    var reference: String
    var clientName: String
    var amount: Double
    var dueDate: String
    var status: String
    var summary: String

    init(reference: String, clientName: String, amount: Double, dueDate: String, status: String, summary: String) {
        self.reference = reference
        self.clientName = clientName
        self.amount = amount
        self.dueDate = dueDate
        self.status = status
        self.summary = summary
    }

    var formattedAmount: String {
        amount.formattedEuro
    }

    var statusValue: QuoteStatus {
        QuoteStatus(rawValue: status) ?? .pending
    }
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

    init(name: String, sku: String, quantity: Int, stockLevel: String, supplier: String, storageLocation: String, minimumQuantity: Int) {
        self.name = name
        self.sku = sku
        self.quantity = quantity
        self.stockLevel = stockLevel
        self.supplier = supplier
        self.storageLocation = storageLocation
        self.minimumQuantity = minimumQuantity
    }

    var levelValue: StockLevel {
        StockLevel(rawValue: stockLevel) ?? .normal
    }
}

private struct ClientDraft {
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

private struct InterventionDraft {
    var id: PersistentIdentifier?
    var clientName = ""
    var location = ""
    var kind = ""
    var scheduledDate = Calendar.current.startOfDay(for: .now)
    var timeSlot = "08:00 - 10:00"
    var priority: PriorityLevel = .normal
    var progress = 0.0
    var notes = ""

    init() {}

    init(intervention: InterventionRecord) {
        id = intervention.persistentModelID
        clientName = intervention.clientName
        location = intervention.location
        kind = intervention.kind
        scheduledDate = intervention.date
        timeSlot = intervention.timeSlot
        priority = intervention.priorityValue
        progress = intervention.progress
        notes = intervention.notes
    }

    var sortDate: Date {
        scheduledDate
    }

    func makeIntervention() -> InterventionRecord {
        InterventionRecord(
            clientName: clientName,
            location: location,
            kind: kind,
            date: scheduledDate,
            timeSlot: timeSlot,
            priority: priority.rawValue,
            progress: progress,
            notes: notes
        )
    }
}

private struct QuoteDraft {
    var id: PersistentIdentifier?
    var reference = ""
    var clientName = ""
    var amount = 0.0
    var dueDate = ""
    var status: QuoteStatus = .pending
    var summary = ""

    init() {}

    init(quote: QuoteRecord) {
        id = quote.persistentModelID
        reference = quote.reference
        clientName = quote.clientName
        amount = quote.amount
        dueDate = quote.dueDate
        status = quote.statusValue
        summary = quote.summary
    }

    func makeQuote() -> QuoteRecord {
        QuoteRecord(reference: reference, clientName: clientName, amount: amount, dueDate: dueDate, status: status.rawValue, summary: summary)
    }
}

private struct InventoryDraft {
    var id: PersistentIdentifier?
    var name = ""
    var sku = ""
    var quantity = 0
    var level: StockLevel = .normal
    var supplier = ""
    var storageLocation = ""
    var minimumQuantity = 0

    init() {}

    init(item: InventoryItemRecord) {
        id = item.persistentModelID
        name = item.name
        sku = item.sku
        quantity = item.quantity
        level = item.levelValue
        supplier = item.supplier
        storageLocation = item.storageLocation
        minimumQuantity = item.minimumQuantity
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
            minimumQuantity: minimumQuantity
        )
    }
}

private enum SampleData {
    static let clients: [ClientRecord] = [
        ClientRecord(name: "Résidence Les Tilleuls", city: "Nîmes", note: "Contrat maintenance parties communes", status: ClientStatus.priority.rawValue, phone: "06 10 10 10 10", email: "syndic@tilleuls.fr", address: "14 avenue des Tilleuls, 30000 Nîmes"),
        ClientRecord(name: "Boulangerie Morel", city: "Uzès", note: "Remise aux normes du tableau électrique", status: ClientStatus.active.rawValue, phone: "06 20 20 20 20", email: "contact@boulangerie-morel.fr", address: "8 place du marché, 30700 Uzès"),
        ClientRecord(name: "M. Durand", city: "Alès", note: "Installation borne de recharge prévue", status: ClientStatus.quote.rawValue, phone: "06 30 30 30 30", email: "durand@orange.fr", address: "22 chemin des Vignes, 30100 Alès")
    ]

    static let interventions: [InterventionRecord] = [
        InterventionRecord(clientName: "Boulangerie Morel", location: "Uzès", kind: "Dépannage chambre froide", date: .now, timeSlot: "08:30 - 10:00", priority: PriorityLevel.urgent.rawValue, progress: 0.85, notes: "Contrôle des protections et remplacement d'un contacteur."),
        InterventionRecord(clientName: "Résidence Les Tilleuls", location: "Nîmes", kind: "Maintenance éclairage hall", date: .now, timeSlot: "10:30 - 12:00", priority: PriorityLevel.normal.rawValue, progress: 0.45, notes: "Vérification minuterie et remplacement de deux luminaires."),
        InterventionRecord(clientName: "M. Durand", location: "Alès", kind: "Visite technique borne IRVE", date: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now, timeSlot: "14:00 - 15:30", priority: PriorityLevel.quote.rawValue, progress: 0.20, notes: "Relevé puissance disponible et passage de câble.")
    ]

    static let quotes: [QuoteRecord] = [
        QuoteRecord(reference: "DEV-2026-014", clientName: "M. Durand", amount: 2850, dueDate: "28 avr.", status: QuoteStatus.pending.rawValue, summary: "Fourniture et pose d'une borne de recharge 7,4 kW avec protection dédiée."),
        QuoteRecord(reference: "FAC-2026-031", clientName: "Résidence Les Tilleuls", amount: 4320, dueDate: "30 avr.", status: QuoteStatus.sent.rawValue, summary: "Maintenance annuelle, remise en état des luminaires et remplacement de disjoncteurs."),
        QuoteRecord(reference: "FAC-2026-027", clientName: "Boulangerie Morel", amount: 1190, dueDate: "22 avr.", status: QuoteStatus.late.rawValue, summary: "Dépannage et sécurisation de l'alimentation de la chambre froide.")
    ]

    static let inventory: [InventoryItemRecord] = [
        InventoryItemRecord(name: "Disjoncteur 20A Legrand", sku: "DJ-20A-LG", quantity: 4, stockLevel: StockLevel.critical.rawValue, supplier: "Rexel Nîmes", storageLocation: "Camionnette A", minimumQuantity: 5),
        InventoryItemRecord(name: "Spots LED IP65", sku: "LED-IP65", quantity: 18, stockLevel: StockLevel.normal.rawValue, supplier: "Sonepar", storageLocation: "Dépôt principal", minimumQuantity: 8),
        InventoryItemRecord(name: "Gaine ICTA 20 mm", sku: "ICTA-20", quantity: 6, stockLevel: StockLevel.warning.rawValue, supplier: "CGED", storageLocation: "Rayon câblage", minimumQuantity: 4)
    ]
}

private extension Double {
    var formattedEuro: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: NSNumber(value: self)) ?? "\(self) €"
    }
}

private extension String {
    var NSString: NSString {
        self as NSString
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [ClientRecord.self, InterventionRecord.self, QuoteRecord.self, InventoryItemRecord.self], inMemory: true)
}
