import Foundation

struct MockAgentService: AgentServicing {
    func updateDraft(
        message: String,
        currentItems: [ProductRequest]
    ) async throws -> AgentResponse {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AgentServiceError.emptyMessage }

        let normalizedMessage = normalize(trimmed)
        if isRemoval(normalizedMessage) {
            return removeProducts(in: normalizedMessage, from: currentItems)
        }

        let parsedItems = parseProducts(from: normalizedMessage)
        guard !parsedItems.isEmpty else { throw AgentServiceError.noProductsFound }

        if isReplacement(normalizedMessage) {
            let updated = replaceProducts(parsedItems, in: currentItems)
            return AgentResponse(
                reply: parsedItems.count == 1
                    ? "Actualicé el producto en tu lista."
                    : "Actualicé los productos en tu lista.",
                draftItems: updated
            )
        }

        let updated = addProducts(parsedItems, to: currentItems)
        return AgentResponse(
            reply: parsedItems.count == 1
                ? "Agregué un producto a tu lista."
                : "Agregué \(parsedItems.count) productos a tu lista.",
            draftItems: updated
        )
    }

    private func parseProducts(from message: String) -> [ProductRequest] {
        let segments = message
            .replacingOccurrences(of: ";", with: ",")
            .replacingOccurrences(of: "\n", with: ",")
            .replacingOccurrences(of: " y ", with: ",")
            .split(separator: ",")
            .map(String.init)

        return segments.compactMap(parseProduct)
    }

    private func parseProduct(_ segment: String) -> ProductRequest? {
        let cleaned = segment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        let catalogEntry = catalog.first { entry in
            entry.aliases.contains { cleaned.contains($0) }
        }
        let amount = extractAmount(from: cleaned)

        guard let catalogEntry else {
            let inferredName = inferUnknownName(from: cleaned)
            guard !inferredName.isEmpty else { return nil }
            return ProductRequest(
                name: inferredName,
                quantity: amount?.quantity ?? 1,
                unit: amount?.unit ?? .piece
            )
        }

        return ProductRequest(
            name: catalogEntry.name,
            quantity: amount?.quantity ?? 1,
            unit: amount?.unit ?? catalogEntry.defaultUnit,
            notes: catalogEntry.notes
        )
    }

    private func extractAmount(from text: String) -> (quantity: Double, unit: ProductUnit?)? {
        let pattern = #"(\d+(?:[\.,]\d+)?)\s*(kilogramos?|kilos?|kg|gramos?|gr|g|litros?|lts?|l|mililitros?|ml|piezas?|unidades?|paquetes?|docenas?)?"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let quantityRange = Range(match.range(at: 1), in: text) {
            let quantityText = text[quantityRange].replacingOccurrences(of: ",", with: ".")
            let quantity = Double(quantityText) ?? 1
            let unit: ProductUnit?
            if match.range(at: 2).location != NSNotFound,
               let unitRange = Range(match.range(at: 2), in: text) {
                unit = productUnit(for: String(text[unitRange]))
            } else {
                unit = nil
            }
            return (quantity, unit)
        }

        let wordAmounts: [(String, Double)] = [
            ("media", 0.5), ("medio", 0.5), ("una", 1), ("un", 1),
            ("dos", 2), ("tres", 3), ("cuatro", 4), ("cinco", 5),
            ("seis", 6), ("doce", 12)
        ]
        let unit = ProductUnit.allCases.first { unit in
            aliases(for: unit).contains { containsWord($0, in: text) }
        }
        guard let wordAmount = wordAmounts.first(where: { containsWord($0.0, in: text) }) else {
            return unit.map { (1, $0) }
        }
        return (wordAmount.1, unit)
    }

    private func addProducts(
        _ newItems: [ProductRequest],
        to currentItems: [ProductRequest]
    ) -> [ProductRequest] {
        newItems.reduce(into: currentItems) { result, item in
            if let index = result.firstIndex(where: { sameProduct($0, item) }) {
                result[index].quantity += item.quantity
            } else {
                result.append(item)
            }
        }
    }

    private func replaceProducts(
        _ replacements: [ProductRequest],
        in currentItems: [ProductRequest]
    ) -> [ProductRequest] {
        replacements.reduce(into: currentItems) { result, replacement in
            if let index = result.firstIndex(where: {
                normalize($0.name) == normalize(replacement.name)
            }) {
                let existingID = result[index].id
                result[index] = replacement
                result[index].id = existingID
            } else {
                result.append(replacement)
            }
        }
    }

    private func removeProducts(
        in message: String,
        from currentItems: [ProductRequest]
    ) -> AgentResponse {
        let retained = currentItems.filter { item in
            !message.contains(normalize(item.name))
        }
        let removedCount = currentItems.count - retained.count
        return AgentResponse(
            reply: removedCount == 0
                ? "No encontré ese producto en tu lista."
                : "Eliminé \(removedCount == 1 ? "el producto" : "los productos") de tu lista.",
            status: removedCount == 0 ? .partial : .complete,
            draftItems: retained
        )
    }

    private func inferUnknownName(from text: String) -> String {
        var value = text
        let removableWords = [
            "agrega", "agregar", "añade", "pon", "quiero", "necesito",
            "cambia", "modifica", "a", "de", "otro", "otra"
        ]
        let pattern = #"\d+(?:[\.,]\d+)?|kilogramos?|kilos?|kg|gramos?|gr|g|litros?|lts?|l|mililitros?|ml|piezas?|unidades?|paquetes?|docenas?"#
        value = value.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        for word in removableWords {
            value = value.replacingOccurrences(
                of: #"\b"# + NSRegularExpression.escapedPattern(for: word) + #"\b"#,
                with: "",
                options: .regularExpression
            )
        }
        value = value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return value.prefix(1).uppercased() + value.dropFirst()
    }

    private func productUnit(for text: String) -> ProductUnit? {
        let normalized = normalize(text)
        return ProductUnit.allCases.first { aliases(for: $0).contains(normalized) }
    }

    private func aliases(for unit: ProductUnit) -> [String] {
        switch unit {
        case .gram: ["g", "gr", "gramo", "gramos"]
        case .kilogram: ["kg", "kilo", "kilos", "kilogramo", "kilogramos"]
        case .milliliter: ["ml", "mililitro", "mililitros"]
        case .liter: ["l", "lt", "lts", "litro", "litros"]
        case .piece: ["pieza", "piezas", "unidad", "unidades"]
        case .package: ["paquete", "paquetes"]
        case .dozen: ["docena", "docenas"]
        }
    }

    private func sameProduct(_ lhs: ProductRequest, _ rhs: ProductRequest) -> Bool {
        normalize(lhs.name) == normalize(rhs.name)
            && lhs.unit == rhs.unit
            && lhs.notes == rhs.notes
    }

    private func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_MX"))
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func containsWord(_ word: String, in text: String) -> Bool {
        text.range(
            of: #"\b"# + NSRegularExpression.escapedPattern(for: word) + #"\b"#,
            options: .regularExpression
        ) != nil
    }

    private func isRemoval(_ message: String) -> Bool {
        ["quita", "elimina", "borra", "sin "].contains { message.contains($0) }
    }

    private func isReplacement(_ message: String) -> Bool {
        ["cambia", "modifica", "actualiza"].contains { message.contains($0) }
    }
}

private struct MockCatalogEntry: Sendable {
    let name: String
    let aliases: [String]
    let defaultUnit: ProductUnit
    let notes: String?
}

private let catalog: [MockCatalogEntry] = [
    MockCatalogEntry(name: "Papel de baño", aliases: ["papel de baño", "papel higienico"], defaultUnit: .package, notes: nil),
    MockCatalogEntry(name: "Pechuga de pollo", aliases: ["pechuga de pollo", "pollo"], defaultUnit: .piece, notes: nil),
    MockCatalogEntry(name: "Leche", aliases: ["leche"], defaultUnit: .piece, notes: nil),
    MockCatalogEntry(name: "Huevos", aliases: ["huevos", "huevo"], defaultUnit: .piece, notes: nil),
    MockCatalogEntry(name: "Arroz", aliases: ["arroz"], defaultUnit: .piece, notes: nil),
    MockCatalogEntry(name: "Manzanas", aliases: ["manzanas", "manzana"], defaultUnit: .piece, notes: nil),
    MockCatalogEntry(name: "Aceite", aliases: ["aceite"], defaultUnit: .piece, notes: nil),
    MockCatalogEntry(name: "Tortillas", aliases: ["tortillas", "tortilla"], defaultUnit: .piece, notes: nil),
    MockCatalogEntry(name: "Café", aliases: ["cafe"], defaultUnit: .piece, notes: nil),
    MockCatalogEntry(name: "Yogur", aliases: ["yogur", "yogurt"], defaultUnit: .piece, notes: nil),
    MockCatalogEntry(name: "Pasta", aliases: ["pasta"], defaultUnit: .piece, notes: nil)
]
