import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PDFFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - PDF Renderer avec pagination

enum PDFRenderer {
    private static let pageWidth: CGFloat  = 595
    private static let pageHeight: CGFloat = 842
    private static let marginX: CGFloat    = 42
    private static let marginBottom: CGFloat = 60

    static func renderQuotePDF(for quote: QuoteRecord) -> Data {
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return Data()
        }

        // — Page 1 —
        beginPage(context, mediaBox: &mediaBox)
        var cursorY: CGFloat = pageHeight - 48

        cursorY = drawHeader(for: quote, context: context, y: cursorY)
        cursorY = drawClientBlock(for: quote, context: context, y: cursorY)
        cursorY = drawSummaryBlock(for: quote, context: context, y: cursorY)
        cursorY = drawLinesTable(for: quote, context: context, startY: cursorY, mediaBox: &mediaBox)

        // totaux + paiements sur la dernière page courante
        drawTotals(for: quote, context: context, bottomY: marginBottom + 120)
        if !quote.payments.isEmpty {
            drawPayments(for: quote, context: context, bottomY: marginBottom)
        }
        drawFooter(context: context)

        context.endPDFPage()
        context.closePDF()
        return data as Data
    }

    // MARK: Helpers de page

    private static func beginPage(_ context: CGContext, mediaBox: inout CGRect) {
        context.beginPDFPage(nil)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    }

    private static func newPage(_ context: CGContext, mediaBox: inout CGRect) -> CGFloat {
        drawFooter(context: context)
        NSGraphicsContext.restoreGraphicsState()
        context.endPDFPage()
        beginPage(context, mediaBox: &mediaBox)
        return pageHeight - 48
    }

    // MARK: Sections

    @discardableResult
    private static func drawHeader(for quote: QuoteRecord, context: CGContext, y: CGFloat) -> CGFloat {
        let title: Attrs = [.font: NSFont.boldSystemFont(ofSize: 24), .foregroundColor: NSColor.black]
        let body: Attrs  = [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.darkGray]
        let right: Attrs = [.font: NSFont.boldSystemFont(ofSize: 13), .foregroundColor: NSColor.black]

        draw("Électricité Perez", at: CGPoint(x: marginX, y: y), attrs: title)
        draw("123 avenue de l'Énergie, 30000 Nîmes", at: CGPoint(x: marginX, y: y - 24), attrs: body)
        draw("contact@electricite-perez.fr  •  06 00 00 00 00", at: CGPoint(x: marginX, y: y - 38), attrs: body)

        draw(quote.documentTypeValue.label.uppercased(), at: CGPoint(x: 410, y: y), attrs: right)
        draw("Réf. \(quote.reference)",   at: CGPoint(x: 410, y: y - 20), attrs: body)
        draw("Échéance \(quote.dueDate)", at: CGPoint(x: 410, y: y - 34), attrs: body)
        draw("Statut \(quote.statusValue.label)", at: CGPoint(x: 410, y: y - 48), attrs: body)

        return y - 70
    }

    @discardableResult
    private static func drawClientBlock(for quote: QuoteRecord, context: CGContext, y: CGFloat) -> CGFloat {
        let heading: Attrs = [.font: NSFont.boldSystemFont(ofSize: 12), .foregroundColor: NSColor.black]
        let body: Attrs    = [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.black]

        NSColor(calibratedWhite: 0.95, alpha: 1).setFill()
        NSBezierPath(roundedRect: CGRect(x: marginX, y: y - 62, width: 511, height: 56), xRadius: 10, yRadius: 10).fill()

        draw("Facturé à",             at: CGPoint(x: 56, y: y - 18), attrs: heading)
        draw(quote.clientName,        at: CGPoint(x: 56, y: y - 34), attrs: body)
        draw(quote.client?.address ?? "Adresse client à compléter", at: CGPoint(x: 56, y: y - 48), attrs: body)

        return y - 76
    }

    @discardableResult
    private static func drawSummaryBlock(for quote: QuoteRecord, context: CGContext, y: CGFloat) -> CGFloat {
        guard !quote.summary.isEmpty else { return y - 8 }
        let body: Attrs = [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.black]
        draw("Description : \(quote.summary)",
             in: CGRect(x: marginX, y: y - 44, width: 511, height: 40),
             attrs: body)
        return y - 52
    }

    // Dessine le tableau des lignes, gère la pagination automatique
    private static func drawLinesTable(
        for quote: QuoteRecord,
        context: CGContext,
        startY: CGFloat,
        mediaBox: inout CGRect
    ) -> CGFloat {

        let headerAttrs: Attrs = [.font: NSFont.boldSystemFont(ofSize: 10), .foregroundColor: NSColor.black]
        let body: Attrs        = [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: NSColor.black]
        let small: Attrs       = [.font: NSFont.systemFont(ofSize: 9),  .foregroundColor: NSColor.darkGray]
        let rowHeight: CGFloat = 36

        // En-tête tableau
        var y = startY
        NSColor(calibratedWhite: 0.92, alpha: 1).setFill()
        NSBezierPath(rect: CGRect(x: marginX, y: y - 22, width: 511, height: 22)).fill()
        draw("Prestation", at: CGPoint(x: 48, y: y - 16), attrs: headerAttrs)
        draw("Qté",        at: CGPoint(x: 292, y: y - 16), attrs: headerAttrs)
        draw("PU HT",      at: CGPoint(x: 338, y: y - 16), attrs: headerAttrs)
        draw("TVA",        at: CGPoint(x: 412, y: y - 16), attrs: headerAttrs)
        draw("Total TTC",  at: CGPoint(x: 462, y: y - 16), attrs: headerAttrs)
        y -= 28

        for line in quote.lines {
            // Nouvelle page si on déborde
            if y - rowHeight < marginBottom + 180 {
                y = newPage(context, mediaBox: &mediaBox)
                // Re-dessiner en-tête tableau sur nouvelle page
                NSColor(calibratedWhite: 0.92, alpha: 1).setFill()
                NSBezierPath(rect: CGRect(x: marginX, y: y - 22, width: 511, height: 22)).fill()
                draw("Prestation (suite)", at: CGPoint(x: 48, y: y - 16), attrs: headerAttrs)
                draw("Qté",   at: CGPoint(x: 292, y: y - 16), attrs: headerAttrs)
                draw("PU HT", at: CGPoint(x: 338, y: y - 16), attrs: headerAttrs)
                draw("TVA",   at: CGPoint(x: 412, y: y - 16), attrs: headerAttrs)
                draw("Total TTC", at: CGPoint(x: 462, y: y - 16), attrs: headerAttrs)
                y -= 28
            }

            draw(line.title,           at: CGPoint(x: 48, y: y - 14), attrs: body)
            draw(line.lineDescription, in: CGRect(x: 48, y: y - 30, width: 215, height: 18), attrs: small)
            draw(line.quantity.cleanNumber,      at: CGPoint(x: 294, y: y - 14), attrs: body)
            draw(line.unitPrice.formattedEuro,   at: CGPoint(x: 336, y: y - 14), attrs: body)
            draw("\(line.taxRate.cleanNumber)%", at: CGPoint(x: 412, y: y - 14), attrs: body)
            draw(line.totalAmount.formattedEuro, at: CGPoint(x: 462, y: y - 14), attrs: body)

            // Séparateur léger
            NSColor(calibratedWhite: 0.88, alpha: 1).setStroke()
            let sep = NSBezierPath()
            sep.move(to: CGPoint(x: marginX, y: y - rowHeight + 2))
            sep.line(to: CGPoint(x: 553, y: y - rowHeight + 2))
            sep.lineWidth = 0.5
            sep.stroke()

            y -= rowHeight
        }

        return y
    }

    private static func drawTotals(for quote: QuoteRecord, context: CGContext, bottomY: CGFloat) {
        let heading: Attrs = [.font: NSFont.boldSystemFont(ofSize: 11), .foregroundColor: NSColor.black]
        let body: Attrs    = [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.black]
        let accent: Attrs  = [.font: NSFont.boldSystemFont(ofSize: 12), .foregroundColor: NSColor.black]

        let rows: [(String, String, Bool)] = [
            ("Total HT",            quote.subtotal.formattedEuro,      false),
            ("TVA",                 quote.taxAmount.formattedEuro,      false),
            ("Total TTC",           quote.totalAmount.formattedEuro,    true),
            ("Acompte théorique",   quote.depositAmount.formattedEuro,  false),
            ("Déjà réglé",          quote.amountPaid.formattedEuro,     false),
            ("Reste à payer",       quote.balanceDue.formattedEuro,     true)
        ]

        var y = bottomY + CGFloat(rows.count * 20)
        for (label, value, bold) in rows {
            let labelAttrs = bold ? accent : heading
            let valueAttrs = bold ? accent : body
            draw(label, at: CGPoint(x: 340, y: y), attrs: labelAttrs)
            draw(value, at: CGPoint(x: 470, y: y), attrs: valueAttrs)
            y -= 20
        }
    }

    private static func drawPayments(for quote: QuoteRecord, context: CGContext, bottomY: CGFloat) {
        let heading: Attrs = [.font: NSFont.boldSystemFont(ofSize: 11), .foregroundColor: NSColor.black]
        let body: Attrs    = [.font: NSFont.systemFont(ofSize: 10),  .foregroundColor: NSColor.black]

        var y = bottomY + CGFloat(min(quote.payments.count, 4) * 18) + 18
        draw("Historique des paiements", at: CGPoint(x: marginX, y: y), attrs: heading)
        y -= 18
        for payment in quote.payments.sorted(by: { $0.paidAt > $1.paidAt }).prefix(4) {
            let line = "\(payment.paidAt.gestionDateString)  •  \(payment.methodValue.label)  •  \(payment.amount.formattedEuro)"
            draw(line, at: CGPoint(x: marginX, y: y), attrs: body)
            if !payment.note.isEmpty {
                draw(payment.note, at: CGPoint(x: marginX + 12, y: y - 12), attrs: body)
                y -= 26
            } else {
                y -= 16
            }
        }
    }

    private static func drawFooter(context: CGContext) {
        let attrs: Attrs = [.font: NSFont.systemFont(ofSize: 9), .foregroundColor: NSColor.lightGray]
        draw("Merci pour votre confiance. Document généré depuis Gestion Électricien.",
             at: CGPoint(x: marginX, y: 28), attrs: attrs)
    }

    // MARK: Draw helpers

    private typealias Attrs = [NSAttributedString.Key: Any]

    private static func draw(_ text: String, at point: CGPoint, attrs: Attrs) {
        (text as NSString).draw(at: point, withAttributes: attrs)
    }

    private static func draw(_ text: String, in rect: CGRect, attrs: Attrs) {
        (text as NSString).draw(in: rect, withAttributes: attrs)
    }
}
