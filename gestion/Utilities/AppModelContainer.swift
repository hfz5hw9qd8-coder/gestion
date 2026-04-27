import SwiftData

enum AppModelContainer {
    static func make() -> ModelContainer {
        let schema: [any PersistentModel.Type] = [
            ClientRecord.self,
            InterventionRecord.self,
            QuoteRecord.self,
            QuoteLineRecord.self,
            PaymentRecord.self,
            InventoryItemRecord.self,
            InventoryMovementRecord.self,
            StockUsageRecord.self
        ]

        do {
            let config = ModelConfiguration(cloudKitDatabase: .automatic)
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            let fallback = ModelConfiguration(cloudKitDatabase: .none)
            return try! ModelContainer(for: schema, configurations: fallback)
        }
    }
}
