import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PDFFileDocument: FileDocument {
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

enum PDFRenderer {
    static func renderQuotePDF(for quote: QuoteRecord) -> Data {
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return Data()
        }

        context.beginPDFPage(nil)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

        drawHeader(for: quote)
        drawClientBlock(for: quote)
        drawSummary(for: quote)
        drawLines(for: quote)
        drawPayments(for: quote)
        drawFooter()

        NSGraphicsContext.restoreGraphicsState()
        context.endPDFPage()
        context.closePDF()
        return data as Data
    }

    private static func drawHeader(for quote: QuoteRecord) {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 26),
            .foregroundColor: NSColor.black
        ]
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.darkGray
        ]
        let headingAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 14),
            .foregroundColor: NSColor.black
        ]

        ("Électricité Perez".nsString).draw(at: CGPoint(x: 42, y: 794), withAttributes: titleAttributes)
        ("123 avenue de l'Énergie, 30000 Nîmes".nsString).draw(at: CGPoint(x: 42, y: 772), withAttributes: bodyAttributes)
        ("contact@electricite-perez.fr • 06 00 00 00 00".nsString).draw(at: CGPoint(x: 42, y: 756), withAttributes: bodyAttributes)

        ("\(quote.documentTypeValue.label.uppercased())".nsString).draw(at: CGPoint(x: 410, y: 794), withAttributes: headingAttributes)
        ("Réf. \(quote.reference)".nsString).draw(at: CGPoint(x: 410, y: 774), withAttributes: bodyAttributes)
        ("Échéance \(quote.dueDate)".nsString).draw(at: CGPoint(x: 410, y: 758), withAttributes: bodyAttributes)
        ("Statut \(quote.statusValue.label)".nsString).draw(at: CGPoint(x: 410, y: 742), withAttributes: bodyAttributes)
    }

    private static func drawClientBlock(for quote: QuoteRecord) {
        let headingAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 13),
            .foregroundColor: NSColor.black
        ]
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.black
        ]

        NSColor(calibratedWhite: 0.95, alpha: 1).setFill()
        NSBezierPath(roundedRect: CGRect(x: 42, y: 660, width: 511, height: 72), xRadius: 12, yRadius: 12).fill()
        ("Facturé à".nsString).draw(at: CGPoint(x: 56, y: 708), withAttributes: headingAttributes)
        (quote.clientName.nsString).draw(at: CGPoint(x: 56, y: 688), withAttributes: bodyAttributes)
        ((quote.client?.address ?? "Adresse client à compléter").nsString).draw(at: CGPoint(x: 56, y: 672), withAttributes: bodyAttributes)
    }

    private static func drawSummary(for quote: QuoteRecord) {
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.black
        ]
        ("Description :\n\(quote.summary)".nsString).draw(
            in: CGRect(x: 42, y: 590, width: 511, height: 52),
            withAttributes: bodyAttributes
        )
    }

    private static func drawLines(for quote: QuoteRecord) {
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 11),
            .foregroundColor: NSColor.black
        ]
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.black
        ]
        let smallAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.darkGray
        ]

        NSColor(calibratedWhite: 0.92, alpha: 1).setFill()
        NSBezierPath(rect: CGRect(x: 42, y: 548, width: 511, height: 24)).fill()
        ("Prestation".nsString).draw(at: CGPoint(x: 48, y: 554), withAttributes: headerAttributes)
        ("Qté".nsString).draw(at: CGPoint(x: 290, y: 554), withAttributes: headerAttributes)
        ("PU HT".nsString).draw(at: CGPoint(x: 340, y: 554), withAttributes: headerAttributes)
        ("TVA".nsString).draw(at: CGPoint(x: 412, y: 554), withAttributes: headerAttributes)
        ("Total".nsString).draw(at: CGPoint(x: 474, y: 554), withAttributes: headerAttributes)

        var currentY: CGFloat = 520
        for line in quote.lines {
            line.title.nsString.draw(at: CGPoint(x: 48, y: currentY + 14), withAttributes: bodyAttributes)
            line.lineDescription.nsString.draw(in: CGRect(x: 48, y: currentY - 2, width: 215, height: 24), withAttributes: smallAttributes)
            line.quantity.cleanNumber.nsString.draw(at: CGPoint(x: 292, y: currentY + 14), withAttributes: bodyAttributes)
            line.unitPrice.formattedEuro.nsString.draw(at: CGPoint(x: 336, y: currentY + 14), withAttributes: bodyAttributes)
            "\(line.taxRate.cleanNumber)%".nsString.draw(at: CGPoint(x: 412, y: currentY + 14), withAttributes: bodyAttributes)
            line.totalAmount.formattedEuro.nsString.draw(at: CGPoint(x: 468, y: currentY + 14), withAttributes: bodyAttributes)
            currentY -= 40
        }

        let totalsY = currentY - 10
        drawTotals(for: quote, y: totalsY)
    }

    private static func drawTotals(for quote: QuoteRecord, y: CGFloat) {
        let headingAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 12),
            .foregroundColor: NSColor.black
        ]
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.black
        ]

        let totals = [
            ("Total HT", quote.subtotal.formattedEuro),
            ("TVA", quote.taxAmount.formattedEuro),
            ("Total TTC", quote.totalAmount.formattedEuro),
            ("Acompte théorique", quote.depositAmount.formattedEuro),
            ("Déjà réglé", quote.amountPaid.formattedEuro),
            ("Reste à payer", quote.balanceDue.formattedEuro)
        ]

        for (index, total) in totals.enumerated() {
            let lineY = y - CGFloat(index * 20)
            total.0.nsString.draw(at: CGPoint(x: 350, y: lineY), withAttributes: headingAttributes)
            total.1.nsString.draw(at: CGPoint(x: 470, y: lineY), withAttributes: bodyAttributes)
        }
    }

    private static func drawPayments(for quote: QuoteRecord) {
        guard !quote.payments.isEmpty else { return }

        let headingAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 12),
            .foregroundColor: NSColor.black
        ]
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.black
        ]

        ("Historique des paiements".nsString).draw(at: CGPoint(x: 42, y: 170), withAttributes: headingAttributes)
        var y: CGFloat = 150
        for payment in quote.payments.sorted(by: { $0.paidAt > $1.paidAt }).prefix(4) {
            let line = "\(payment.paidAt.gestionDateString) • \(payment.methodValue.label) • \(payment.amount.formattedEuro)"
            line.nsString.draw(at: CGPoint(x: 42, y: y), withAttributes: bodyAttributes)
            if !payment.note.isEmpty {
                payment.note.nsString.draw(at: CGPoint(x: 62, y: y - 14), withAttributes: bodyAttributes)
                y -= 30
            } else {
                y -= 18
            }
        }
    }

    private static func drawFooter() {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.darkGray
        ]
        ("Merci pour votre confiance. Document généré depuis Gestion Électricien.".nsString)
            .draw(at: CGPoint(x: 42, y: 40), withAttributes: attrs)
    }
}
