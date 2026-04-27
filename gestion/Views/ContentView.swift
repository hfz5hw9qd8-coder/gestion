import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClientRecord.name) private var clients: [ClientRecord]
    @Query(sort: \InterventionRecord.sortDate) private var interventions: [InterventionRecord]
    @Query(sort: \QuoteRecord.reference, order: .reverse) private var quotes: [QuoteRecord]
    @Query(sort: \InventoryItemRecord.name) private var inventory: [InventoryItemRecord]
    @State private var viewModel = GestionViewModel()

    private var viewState: GestionViewState {
        viewModel.makeViewState(
            clients: clients,
            interventions: interventions,
            quotes: quotes,
            inventory: inventory
        )
    }

    private var clientOptions: [ClientOption] {
        viewModel.clientOptions(from: clients)
    }

    private var inventoryOptions: [InventoryOption] {
        viewModel.inventoryOptions(from: inventory)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.97, green: 0.95, blue: 0.92),
                        Color(red: 0.90, green: 0.93, blue: 0.95)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        heroSection
                        tabSelector

                        switch viewModel.selectedTab {
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
            .searchable(text: $viewModel.searchText, prompt: "Client, chantier, référence, matériel")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if viewModel.canAddCurrentTabItem {
                        Button(action: viewModel.presentNewForm) {
                            Label("Ajouter", systemImage: "plus")
                        }
                    }
                }
            }
            .sheet(item: $viewModel.activeSheet) { sheet in
                editorSheetContent(for: sheet)
            }
            .fileExporter(
                isPresented: $viewModel.isShowingExporter,
                document: viewModel.exportDocument,
                contentType: .pdf,
                defaultFilename: viewModel.quoteToExport?.reference.replacingOccurrences(of: "/", with: "-") ?? "document"
            ) { _ in
                viewModel.clearExportState()
            }
            .alert(item: $viewModel.deletionTarget) { target in
                Alert(
                    title: Text("Supprimer \(target.kind)?"),
                    message: Text("Cette action est définitive."),
                    primaryButton: .destructive(Text("Supprimer")) {
                        viewModel.delete(target, in: modelContext)
                    },
                    secondaryButton: .cancel()
                )
            }
            .task {
                viewModel.seedDataIfNeeded(
                    clients: clients,
                    interventions: interventions,
                    quotes: quotes,
                    inventory: inventory,
                    in: modelContext
                )
            }
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Gestion atelier & chantiers")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.8))

                    Text("Paiements, planning, stock et documents reliés.")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Synchronisation SwiftData prête pour iCloud si la capacité CloudKit est activée dans le projet.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer()

                VStack(alignment: .leading, spacing: 10) {
                    Label("\(viewState.todaysInterventionCount) interventions aujourd'hui", systemImage: "bolt.badge.clock")
                    Label("\(viewState.pendingQuoteCount) documents à valider", systemImage: "doc.text.magnifyingglass")
                    Label("\(viewState.outstandingBalance.formattedEuro) restant à encaisser", systemImage: "eurosign.circle")
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .padding(16)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.17, green: 0.19, blue: 0.23),
                            Color(red: 0.92, green: 0.48, blue: 0.16)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 78))
                .foregroundStyle(.white.opacity(0.14))
                .padding(24)
        }
        .shadow(color: .black.opacity(0.12), radius: 18, y: 10)
    }

    private var tabSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(WorkspaceTab.allCases) { tab in
                    Button {
                        viewModel.selectedTab = tab
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: tab.icon)
                            Text(tab.title)
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(viewModel.selectedTab == tab ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(viewModel.selectedTab == tab ? Color.black : Color.white.opacity(0.75))
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
                ForEach(viewState.metrics) { metric in
                    MetricCard(metric: metric)
                }
            }

            contentPanel(title: "Signaux à surveiller", systemImage: "scope") {
                LazyVStack(spacing: 12) {
                    ForEach(viewState.highlights) { item in
                        HighlightCard(item: item)
                    }
                }
            }

            contentPanel(title: "Planning du jour", systemImage: "calendar") {
                LazyVStack(spacing: 12) {
                    ForEach(viewState.upcomingInterventions.prefix(3)) { intervention in
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
            sectionHeader(title: "Planning", subtitle: "\(viewState.filteredInterventions.count) interventions")

            Picker("Filtre planning", selection: $viewModel.planningFilter) {
                ForEach(PlanningFilter.allCases) { filter in
                    Text(filter.label).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            contentPanel(title: "Agenda des chantiers", systemImage: "calendar.badge.clock") {
                LazyVStack(spacing: 18) {
                    ForEach(viewState.groupedInterventions, id: \.date) { group in
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
                                            StatusBadge(title: intervention.statusValue.label, color: intervention.statusValue.color)
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
                LazyVStack(spacing: 12) {
                    ForEach(viewState.filteredClients) { client in
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
                                            Label("\(client.interventions.count) interventions", systemImage: "bolt.circle")
                                            Spacer()
                                            Label(client.outstandingBalance.formattedEuro, systemImage: "eurosign.circle")
                                        }
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                    }
                                }
                            } menu: {
                                rowMenu(
                                    editAction: { viewModel.activeSheet = .client(ClientDraft(client: client)) },
                                    deleteAction: { viewModel.deletionTarget = .client(client.persistentModelID) }
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
                LazyVStack(spacing: 12) {
                    ForEach(viewState.filteredInterventions) { intervention in
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
                                        StatusBadge(title: intervention.statusValue.label, color: intervention.statusValue.color)
                                    }

                                    HStack {
                                        Label(intervention.kind, systemImage: "wrench.and.screwdriver")
                                        Spacer()
                                        Label(intervention.timeSlot, systemImage: "clock")
                                    }
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(.secondary)

                                    HStack {
                                        Text(intervention.dateLabel)
                                            .font(.footnote.weight(.semibold))
                                        Spacer()
                                        Text("\(intervention.usedItemsCount) unités • \(intervention.usedItemsCost.formattedEuro)")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }

                                    ProgressView(value: intervention.progress)
                                        .tint(intervention.priorityValue.color)
                                }
                            } menu: {
                                rowMenu(
                                    editAction: { viewModel.activeSheet = .intervention(InterventionDraft(intervention: intervention)) },
                                    deleteAction: { viewModel.deletionTarget = .intervention(intervention.persistentModelID) }
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
                LazyVStack(spacing: 12) {
                    ForEach(viewState.filteredQuotes) { quote in
                        NavigationLink {
                            QuoteDetailView(quote: quote) {
                                viewModel.exportPDF(for: quote)
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
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(quote.reference)
                                                    .font(.headline)
                                                Text(quote.documentTypeValue.label)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Text(quote.formattedAmount)
                                                .font(.headline)
                                        }

                                        Text(quote.clientName)
                                            .foregroundStyle(.secondary)

                                        HStack {
                                            StatusBadge(title: quote.statusValue.label, color: quote.statusValue.color)
                                            Spacer()
                                            Text("Réglé \(quote.amountPaid.formattedEuro) • reste \(quote.balanceDue.formattedEuro)")
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            } menu: {
                                Button("Exporter PDF", systemImage: "document.badge.gearshape") {
                                    viewModel.exportPDF(for: quote)
                                }
                                Button("Modifier", systemImage: "pencil") {
                                    viewModel.activeSheet = .quote(QuoteDraft(quote: quote))
                                }
                                Button("Supprimer", systemImage: "trash", role: .destructive) {
                                    viewModel.deletionTarget = .quote(quote.persistentModelID)
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

            contentPanel(title: "Valorisation et réapprovisionnement", systemImage: "shippingbox") {
                LazyVStack(spacing: 12) {
                    ForEach(viewState.filteredInventory) { item in
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
                                        Text("\(item.availableQuantity) dispo • valeur \(item.currentValue.formattedEuro)")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("\(item.movements.count) mouvements")
                                            .font(.headline)
                                        StatusBadge(title: item.levelValue.label, color: item.levelValue.color)
                                    }
                                }
                            } menu: {
                                rowMenu(
                                    editAction: { viewModel.activeSheet = .inventory(InventoryDraft(item: item)) },
                                    deleteAction: { viewModel.deletionTarget = .inventory(item.persistentModelID) }
                                )
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
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

            VStack(alignment: .trailing, spacing: 4) {
                StatusBadge(title: intervention.statusValue.label, color: intervention.statusValue.color)
                Text(intervention.usedItemsCost.formattedEuro)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
        .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func rowMenu(editAction: @escaping () -> Void, deleteAction: @escaping () -> Void) -> some View {
        Button("Modifier", systemImage: "pencil", action: editAction)
        Button("Supprimer", systemImage: "trash", role: .destructive, action: deleteAction)
    }

    @ViewBuilder
    private func editorSheetContent(for sheet: EditorSheet) -> some View {
        switch sheet {
        case .client(let draft):
            ClientFormView(draft: draft) { viewModel.saveClient($0, in: modelContext) }
        case .intervention(let draft):
            InterventionFormView(
                draft: draft,
                clients: clientOptions,
                inventoryOptions: inventoryOptions
            ) {
                viewModel.saveIntervention($0, in: modelContext)
            }
        case .quote(let draft):
            QuoteFormView(draft: draft, clients: clientOptions) {
                viewModel.saveQuote($0, in: modelContext)
            }
        case .inventory(let draft):
            InventoryFormView(draft: draft) { viewModel.saveInventory($0, in: modelContext) }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            ClientRecord.self,
            InterventionRecord.self,
            QuoteRecord.self,
            QuoteLineRecord.self,
            PaymentRecord.self,
            InventoryItemRecord.self,
            InventoryMovementRecord.self,
            StockUsageRecord.self
        ], inMemory: true)
}
