import SwiftUI

// MARK: - CLIENT

struct ClientDetailView: View {
    let client: Client

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                DetailHero(
                    title: client.name,
                    subtitle: client.city,
                    color: client.statusValue.color,
                    systemImage: "person.2.fill"
                )

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

// MARK: - INTERVENTION

struct InterventionDetailView: View {
    let intervention: Intervention

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                DetailHero(
                    title: intervention.clientName,
                    subtitle: intervention.kind,
                    color: intervention.priorityValue.color,
                    systemImage: "bolt.fill"
                )

                DetailSection(title: "Organisation") {
                    InfoRow(label: "Date", value: intervention.dateLabel)
                    InfoRow(label: "Créneau", value: intervention.timeSlot)
                    InfoRow(label: "Lieu", value: intervention.location)
                    InfoRow(label: "Priorité", value: intervention.priorityValue.rawValue)
                    InfoRow(label: "État", value: intervention.statusValue.rawValue)
                }

                DetailSection(title: "Matériel utilisé") {
                    if intervention.stockUsages.isEmpty {
                        Text("Aucune sortie de stock.")
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

                DetailSection(title: "Notes") {
                    Text(intervention.notes)
                        .font(.subheadline)
                }
            }
            .padding(20)
        }
        .navigationTitle("Intervention")
    }
}

// MARK: - QUOTE

struct QuoteDetailView: View {
    let quote: Quote
    let onExportPDF: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                DetailHero(
                    title: quote.reference,
                    subtitle: "\(quote.documentTypeValue.label) • \(quote.clientName)",
                    color: quote.statusValue.color,
                    systemImage: "doc.text.fill"
                )

                DetailSection(title: "Document") {
                    InfoRow(label: "Total HT", value: quote.subtotal.formattedEuro)
                    InfoRow(label: "TVA", value: quote.taxAmount.formattedEuro)
                    InfoRow(label: "Total TTC", value: quote.totalAmount.formattedEuro)
                    InfoRow(label: "Acompte", value: quote.depositAmount.formattedEuro)
                    InfoRow(label: "Payé", value: quote.amountPaid.formattedEuro)
                    InfoRow(label: "Reste", value: quote.balanceDue.formattedEuro)
                    InfoRow(label: "Échéance", value: quote.dueDate.gestionDateString)
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
                        Text("Aucun paiement.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(quote.payments.sorted { $0.paidAt > $1.paidAt }) { payment in
                            VStack(alignment: .leading, spacing: 4) {

                                HStack {
                                    Text(payment.amount.formattedEuro)
                                        .font(.headline)
                                    Spacer()
                                    Text(payment.method)
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

// MARK: - INVENTORY

struct InventoryDetailView: View {
    let item: InventoryItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                DetailHero(
                    title: item.name,
                    subtitle: item.sku,
                    color: item.levelValue.color,
                    systemImage: "shippingbox.fill"
                )

                DetailSection(title: "Stock") {
                    InfoRow(label: "Stock initial", value: "\(item.quantity)")
                    InfoRow(label: "Sorties", value: "\(item.usedQuantity)")
                    InfoRow(label: "Disponible", value: "\(item.availableQuantity)")
                    InfoRow(label: "Valeur", value: item.currentValue.formattedEuro)
                    InfoRow(label: "Seuil", value: "\(item.minimumQuantity)")
                    InfoRow(label: "Coût unitaire", value: item.unitCost.formattedEuro)
                    InfoRow(label: "Niveau", value: item.levelValue.rawValue)
                }

                DetailSection(title: "Approvisionnement") {
                    InfoRow(label: "Fournisseur", value: item.supplier)
                    InfoRow(label: "Emplacement", value: item.location)
                }

                DetailSection(title: "Mouvements") {
                    ForEach(item.movements.sorted { $0.date > $1.date }) { movement in
                        VStack(alignment: .leading, spacing: 4) {

                            HStack {
                                Text(movement.type)
                                    .font(.headline)
                                Spacer()
                                Text("\(movement.quantity)")
                                    .font(.headline)
                            }

                            Text(movement.date.gestionDateString)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Matériel")
    }
}

// MARK: - FIXES (EXTENSIONS)

// CLIENT


// INTERVENTION
extension StockUsage {
    var totalCost: Double {
        Double(quantityUsed) * 10 // placeholder (remplacer par prix réel si dispo)
    }
}



// MOVEMENT COMPAT
extension InventoryMovement : Identifiable {
    var id: UUID { UUID() }

    var quantityDelta: Int { quantity }
    var typeValue: String { type }
    var movedAt: Date { date }
}

// PAYMENT COMPAT
extension Payment{
    var methodValue: String { method }
}
