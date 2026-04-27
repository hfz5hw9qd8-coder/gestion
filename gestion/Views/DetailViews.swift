import SwiftUI

struct ClientDetailView: View {
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
                    InfoRow(label: "Interventions", value: "\(client.interventions.count)")
                    InfoRow(label: "Documents", value: "\(client.quotes.count)")
                    InfoRow(label: "Reste à encaisser", value: client.outstandingBalance.formattedEuro)
                }
            }
            .padding(20)
        }
        .navigationTitle("Fiche client")
    }
}

struct InterventionDetailView: View {
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
                    InfoRow(label: "État", value: intervention.statusValue.label)
                }
                DetailSection(title: "Avancement") {
                    ProgressView(value: intervention.progress)
                        .tint(intervention.priorityValue.color)
                    InfoRow(label: "Progression", value: "\(Int(intervention.progress * 100)) %")
                    InfoRow(label: "Coût matériel", value: intervention.usedItemsCost.formattedEuro)
                    InfoRow(label: "Notes", value: intervention.notes)
                }
                DetailSection(title: "Matériel utilisé") {
                    if intervention.stockUsages.isEmpty {
                        Text("Aucune sortie de stock liée.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(intervention.stockUsages) { usage in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(usage.inventoryItemName)
                                    .font(.headline)
                                Text("\(usage.quantityUsed) unités • \(usage.totalCost.formattedEuro)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Intervention")
    }
}

struct QuoteDetailView: View {
    let quote: QuoteRecord
    let onExportPDF: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DetailHero(title: quote.reference, subtitle: "\(quote.documentTypeValue.label) • \(quote.clientName)", color: quote.statusValue.color, systemImage: "doc.text.fill")
                DetailSection(title: "Document") {
                    InfoRow(label: "Total HT", value: quote.subtotal.formattedEuro)
                    InfoRow(label: "TVA", value: quote.taxAmount.formattedEuro)
                    InfoRow(label: "Total TTC", value: quote.totalAmount.formattedEuro)
                    InfoRow(label: "Acompte théorique", value: quote.depositAmount.formattedEuro)
                    InfoRow(label: "Déjà réglé", value: quote.amountPaid.formattedEuro)
                    InfoRow(label: "Reste", value: quote.balanceDue.formattedEuro)
                    InfoRow(label: "Échéance", value: quote.dueDate)
                    InfoRow(label: "Statut", value: quote.statusValue.label)
                }
                DetailSection(title: "Prestations") {
                    ForEach(quote.lines) { line in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(line.title)
                                    .font(.headline)
                                Spacer()
                                Text(line.totalAmount.formattedEuro)
                                    .font(.headline)
                            }
                            Text(line.lineDescription)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text("\(line.quantity.cleanNumber) x \(line.unitPrice.formattedEuro) • TVA \(line.taxRate.cleanNumber)%")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                DetailSection(title: "Paiements") {
                    if quote.payments.isEmpty {
                        Text("Aucun règlement enregistré.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(quote.payments.sorted { $0.paidAt > $1.paidAt }) { payment in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(payment.amount.formattedEuro)
                                        .font(.headline)
                                    Spacer()
                                    Text(payment.methodValue.label)
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                Text(payment.paidAt.gestionDateString)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                if !payment.note.isEmpty {
                                    Text(payment.note)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                DetailSection(title: "Description") {
                    Text(quote.summary)
                        .font(.subheadline)
                }
                Button(action: onExportPDF) {
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

struct InventoryDetailView: View {
    let item: InventoryItemRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DetailHero(title: item.name, subtitle: item.sku, color: item.levelValue.color, systemImage: "shippingbox.fill")
                DetailSection(title: "Stock") {
                    InfoRow(label: "Stock d'ouverture", value: "\(item.quantity) unités")
                    InfoRow(label: "Mouvements", value: "\(item.movementDelta >= 0 ? "+" : "")\(item.movementDelta) unités")
                    InfoRow(label: "Sorties liées", value: "\(item.usedQuantity) unités")
                    InfoRow(label: "Disponible", value: "\(item.availableQuantity) unités")
                    InfoRow(label: "Valeur actuelle", value: item.currentValue.formattedEuro)
                    InfoRow(label: "Seuil d'alerte", value: "\(item.minimumQuantity) unités")
                    InfoRow(label: "Coût unitaire", value: item.unitCost.formattedEuro)
                    InfoRow(label: "Niveau", value: item.levelValue.label)
                }
                DetailSection(title: "Approvisionnement") {
                    InfoRow(label: "Fournisseur", value: item.supplier)
                    InfoRow(label: "Emplacement", value: item.storageLocation)
                }
                DetailSection(title: "Historique") {
                    ForEach(item.movements.sorted { $0.movedAt > $1.movedAt }) { movement in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(movement.typeValue.label)
                                    .font(.headline)
                                Spacer()
                                Text("\(movement.quantityDelta >= 0 ? "+" : "")\(movement.quantityDelta)")
                                    .font(.headline)
                            }
                            Text(movement.movedAt.gestionDateString)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            if !movement.note.isEmpty {
                                Text(movement.note)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Matériel")
    }
}
