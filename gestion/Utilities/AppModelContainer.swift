import SwiftData

enum AppModelContainer {
    static func make() -> ModelContainer {
        let schema = Schema([
            Client.self,
            Intervention.self,
            Quote.self,
            QuoteLine.self,
            Payment.self,
            InventoryItem.self,
            InventoryMovement.self,
            StockUsage.self
        ])

        // Tentative 1 : avec CloudKit
        if let container = try? ModelContainer(
            for: schema,
            configurations: ModelConfiguration(cloudKitDatabase: .automatic)
        ) {
            return container
        }

        // Tentative 2 : sans CloudKit (réseau indisponible, entitlements manquants…)
        if let container = try? ModelContainer(
            for: schema,
            configurations: ModelConfiguration(cloudKitDatabase: .none)
        ) {
            return container
        }

        // Tentative 3 : stockage en mémoire (dernier recours, jamais crasher)
        do {
            return try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        } catch {
            fatalError("Impossible de créer le ModelContainer : \(error)")
        }
    }
}
