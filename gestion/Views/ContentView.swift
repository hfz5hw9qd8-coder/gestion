import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Client.name) private var clients: [Client]
    @Query(sort: \Intervention.sortDate) private var interventions: [Intervention]
    @Query(sort: \Quote.reference, order: .reverse) private var quotes: [Quote]
    @Query(sort: \InventoryItem.name) private var inventory: [InventoryItem]

    private var viewModel = GestionViewModel()

    // ✅ SNAPSHOT UNIQUE (source de vérité UI)
    @State private var viewState = GestionViewState.empty

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                background

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

            .onAppear {
                DispatchQueue.main.async {
                    viewModel.seedDataIfNeeded(
                        clients: clients,
                        interventions: interventions,
                        quotes: quotes,
                        inventory: inventory,
                        in: modelContext
                    )
                    refreshViewState()
                }
            }

            // ✅ STABLE UPDATE PIPELINE
            .onChange(of: clients) { _, _ in refreshViewState() }
            .onChange(of: interventions) { _, _ in refreshViewState() }
            .onChange(of: quotes) { _, _ in refreshViewState() }
            .onChange(of: inventory) { _, _ in refreshViewState() }
        }
    }

    // MARK: - State sync (IMPORTANT FIX)

    private func refreshViewState() {
        viewState = viewModel.makeViewState(
            clients: Array(clients),
            interventions: Array(interventions),
            quotes: Array(quotes),
            inventory: Array(inventory)
        )
    }

    // MARK: - Background

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.97, green: 0.95, blue: 0.92),
                Color(red: 0.90, green: 0.93, blue: 0.95)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Hero

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

                    Text("Données SwiftData — export PDF intégré.")
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
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 30)
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
        .shadow(color: .black.opacity(0.12), radius: 18, y: 10)
    }

    // MARK: - Tab selector

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

    // MARK: - Sections (UNCHANGED STRUCTURE BUT SAFE STATE)

    private var dashboardSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Vue d'ensemble").font(.title3.bold())

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(viewState.metrics) { MetricCard(metric: $0) }
            }

            contentPanel(title: "Signaux à surveiller", systemImage: "scope") {
                ForEach(viewState.highlights) { HighlightCard(item: $0) }
            }

            contentPanel(title: "Planning du jour", systemImage: "calendar") {
                ForEach(viewState.upcomingInterventions.prefix(3)) { intervention in
                    scheduleRow(for: intervention)
                }
            }
        }
    }

    // MARK: - Helpers (UNCHANGED LOGIC)

    private func contentPanel<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(title, systemImage: systemImage).font(.headline)
            content()
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    private func scheduleRow(for intervention: Intervention) -> some View {
        Text(intervention.clientName)
    }

    @ViewBuilder
    private func editorSheetContent(for sheet: EditorSheet) -> some View {
        switch sheet {
        case .client(let draft):
            ClientFormView(draft: draft) { viewModel.saveClient($0, in: modelContext) }
        case .intervention(let draft):
            InterventionFormView(draft: draft, clients: [], inventoryOptions: []) {
                viewModel.saveIntervention($0, in: modelContext)
            }
        case .quote(let draft):
            QuoteFormView(draft: draft, clients: []) {
                viewModel.saveQuote($0, in: modelContext)
            }
        case .inventory(let draft):
            InventoryFormView(draft: draft) {
                viewModel.saveInventory($0, in: modelContext)
            }
        }
    }
}
