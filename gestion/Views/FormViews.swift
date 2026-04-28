import SwiftData
import SwiftUI

struct ClientFormView: View {
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

struct InterventionFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State var draft: InterventionDraft
    let clients: [ClientOption]
    let inventoryOptions: [InventoryOption]
    let onSave: (InterventionDraft) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Intervention") {
                    Picker("Client", selection: $draft.clientID) {
                        Text("Aucun").tag(nil as PersistentIdentifier?)
                        ForEach(clients) { client in
                            Text(client.name).tag(Optional(client.id))
                        }
                    }
                    .onChange(of: draft.clientID) { _, newValue in
                        if let id = newValue, let client = clients.first(where: { $0.id == id }) {
                            draft.clientName = client.name
                        }
                    }
                    TextField("Nom affiché client", text: $draft.clientName)
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
                    Picker("État", selection: $draft.executionStatus) {
                        ForEach(InterventionStatus.allCases) { status in
                            Text(status.label).tag(status)
                        }
                    }
                }
                Section("Suivi") {
                    Slider(value: $draft.progress, in: 0...1)
                    Text("Progression : \(Int(draft.progress * 100)) %")
                    TextField("Notes", text: $draft.notes, axis: .vertical)
                }
                Section("Matériel sorti") {
                    ForEach($draft.stockUsages) { $usage in
                        VStack(alignment: .leading, spacing: 8) {
                            Picker("Article", selection: $usage.inventoryItemID) {
                                Text("Aucun").tag(PersistentIdentifier?.none)
                                ForEach(inventoryOptions) { option in
                                    Text("\(option.name) (\(option.availableQuantity) dispo)").tag(Optional(option.id))
                                }
                            }
                            .onChange(of: usage.inventoryItemID) { _, newValue in
                                guard let id = newValue, let option = inventoryOptions.first(where: { $0.id == id }) else { return }
                                usage.inventoryItemName = option.name
                                usage.unitCost = option.unitCost
                            }
                            Stepper("Quantité utilisée : \(usage.quantityUsed)", value: $usage.quantityUsed, in: 1...999)
                        }
                    }
                    .onDelete { offsets in
                        draft.stockUsages.remove(atOffsets: offsets)
                    }

                    Button("Ajouter un article", systemImage: "plus") {
                        draft.stockUsages.append(StockUsageDraft())
                    }
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

struct QuoteFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State var draft: QuoteDraft
    let clients: [ClientOption]
    let onSave: (QuoteDraft) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Document") {
                    Picker("Type", selection: $draft.documentType) {
                        ForEach(QuoteDocumentType.allCases) { type in
                            Text(type.label).tag(type)
                        }
                    }
                    Picker("Client", selection: $draft.clientID) {
                        Text("Aucun").tag(PersistentIdentifier?.none)
                        ForEach(clients) { client in
                            Text(client.name).tag(Optional(client.id))
                        }
                    }
                    .onChange(of: draft.clientID) { _, newValue in
                        if let id = newValue, let client = clients.first(where: { $0.id == id }) {
                            draft.clientName = client.name
                        }
                    }
                    TextField("Référence", text: $draft.reference)
                    TextField("Nom affiché client", text: $draft.clientName)
                    TextField("Échéance", text: $draft.dueDate)
                    Picker("Statut", selection: $draft.status) {
                        ForEach(QuoteStatus.allCases) { status in
                            Text(status.label).tag(status)
                        }
                    }
                    HStack {
                        Text("Acompte")
                        Spacer()
                        Text("\(draft.depositRate.cleanNumber) %")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $draft.depositRate, in: 0...100, step: 5)
                }
                Section("Lignes") {
                    ForEach($draft.lines) { $line in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Titre", text: $line.title)
                            TextField("Description", text: $line.lineDescription, axis: .vertical)
                            HStack {
                                TextField("Qté", value: $line.quantity, format: .number)
                                TextField("PU HT", value: $line.unitPrice, format: .number)
                                TextField("TVA %", value: $line.taxRate, format: .number)
                            }
                            Text("Sous-total : \(line.subtotal.formattedEuro)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                    .onDelete { offsets in
                        draft.lines.remove(atOffsets: offsets)
                        if draft.lines.isEmpty {
                            draft.lines.append(QuoteLineDraft())
                        }
                    }

                    Button("Ajouter une ligne", systemImage: "plus") {
                        draft.lines.append(QuoteLineDraft())
                    }
                }
                Section("Paiements") {
                    ForEach($draft.payments) { $payment in
                        VStack(alignment: .leading, spacing: 8) {
                            DatePicker("Date", selection: $payment.paidAt, displayedComponents: .date)
                            Picker("Mode", selection: $payment.method) {
                                ForEach(PaymentMethod.allCases) { method in
                                    Text(method.label).tag(method)
                                }
                            }
                            TextField("Montant", value: $payment.amount, format: .number)
                            TextField("Note", text: $payment.note)
                        }
                        .padding(.vertical, 6)
                    }
                    .onDelete { offsets in
                        draft.payments.remove(atOffsets: offsets)
                    }

                    Button("Ajouter un paiement", systemImage: "plus") {
                        draft.payments.append(PaymentDraft())
                    }
                }
                Section("Résumé et totaux") {
                    TextField("Description", text: $draft.summary, axis: .vertical)
                    InfoRow(label: "Total HT", value: draft.subtotal.formattedEuro)
                    InfoRow(label: "TVA", value: draft.taxAmount.formattedEuro)
                    InfoRow(label: "Total TTC", value: draft.totalAmount.formattedEuro)
                    InfoRow(label: "Déjà réglé", value: draft.amountPaid.formattedEuro)
                    InfoRow(label: "Reste à encaisser", value: draft.balanceDue.formattedEuro)
                }
            }
            .navigationTitle(draft.id == nil ? "Nouveau document" : "Modifier document")
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

struct InventoryFormView: View {
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
                    Stepper("Stock d'ouverture : \(draft.quantity)", value: $draft.quantity, in: 0...999)
                    Stepper("Seuil d'alerte : \(draft.minimumQuantity)", value: $draft.minimumQuantity, in: 0...999)
                    TextField("Coût unitaire HT", value: $draft.unitCost, format: .number)
                    Picker("Niveau manuel", selection: $draft.level) {
                        ForEach(StockLevel.allCases) { level in
                            Text(level.label).tag(level)
                        }
                    }
                }
                Section("Historique des mouvements") {
                    ForEach($draft.movements) { $movement in
                        VStack(alignment: .leading, spacing: 8) {
                            DatePicker("Date", selection: $movement.movedAt, displayedComponents: .date)
                            Picker("Type", selection: $movement.type) {
                                ForEach(InventoryMovementType.allCases) { type in
                                    Text(type.label).tag(type)
                                }
                            }
                            Stepper("Variation : \(movement.quantityDelta)", value: $movement.quantityDelta, in: -999...999)
                            TextField("Note", text: $movement.note)
                        }
                        .padding(.vertical, 6)
                    }
                    .onDelete { offsets in
                        draft.movements.remove(atOffsets: offsets)
                    }

                    Button("Ajouter un mouvement", systemImage: "plus") {
                        draft.movements.append(InventoryMovementDraft())
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
