import Foundation
import SwiftData
import SwiftUI

struct GestionViewState {

    // MARK: - Data
    let filteredClients: [Client]
    let filteredInterventions: [Intervention]
    let filteredQuotes: [Quote]
    let filteredInventory: [InventoryItem]

    // MARK: - Dashboard
    let metrics: [DashboardMetric]
    let highlights: [DashboardHighlight]

    // MARK: - Planning
    let upcomingInterventions: [Intervention]
    let groupedInterventions: [(date: String, items: [Intervention])]

    // MARK: - KPIs
    let todaysInterventionCount: Int
    let pendingQuoteCount: Int
    let criticalStockCount: Int
    let monthlyRevenue: Double
    let outstandingBalance: Double

    // MARK: - Designated initializer (clean + defaults safe)
    init(
        filteredClients: [Client] = [],
        filteredInterventions: [Intervention] = [],
        filteredQuotes: [Quote] = [],
        filteredInventory: [InventoryItem] = [],
        metrics: [DashboardMetric] = [],
        highlights: [DashboardHighlight] = [],
        upcomingInterventions: [Intervention] = [],
        groupedInterventions: [(date: String, items: [Intervention])] = [],
        todaysInterventionCount: Int = 0,
        pendingQuoteCount: Int = 0,
        criticalStockCount: Int = 0,
        monthlyRevenue: Double = 0,
        outstandingBalance: Double = 0
    ) {
        self.filteredClients = filteredClients
        self.filteredInterventions = filteredInterventions
        self.filteredQuotes = filteredQuotes
        self.filteredInventory = filteredInventory
        self.metrics = metrics
        self.highlights = highlights
        self.upcomingInterventions = upcomingInterventions
        self.groupedInterventions = groupedInterventions
        self.todaysInterventionCount = todaysInterventionCount
        self.pendingQuoteCount = pendingQuoteCount
        self.criticalStockCount = criticalStockCount
        self.monthlyRevenue = monthlyRevenue
        self.outstandingBalance = outstandingBalance
    }
}

// MARK: - Empty state
extension GestionViewState {
    static var empty: GestionViewState {
        GestionViewState(
            filteredClients: [],
            filteredInterventions: [],
            filteredQuotes: [],
            filteredInventory: [],
            metrics: [],
            highlights: [],
            upcomingInterventions: [],
            groupedInterventions: [],
            todaysInterventionCount: 0,
            pendingQuoteCount: 0,
            criticalStockCount: 0,
            monthlyRevenue: 0,
            outstandingBalance: 0
        )
    }
}

