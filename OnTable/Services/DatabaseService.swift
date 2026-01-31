import Foundation
import SQLite
import Combine

class DatabaseService: ObservableObject {
    static let shared = DatabaseService()

    @Published var decisions: [Decision] = []

    private let db: Connection?

    private init() {
        self.db = DatabaseManager.shared.db
        loadDecisions()
    }

    // MARK: - Load All Decisions

    func loadDecisions() {
        guard let db = db else { return }

        do {
            var loadedDecisions: [Decision] = []

            let stmt = try db.prepare("SELECT id FROM decisions ORDER BY created_at DESC")
            for row in stmt {
                if let id = row[0] as? String {
                    if let decision = try loadDecision(id: id) {
                        loadedDecisions.append(decision)
                    }
                }
            }

            DispatchQueue.main.async {
                self.decisions = loadedDecisions
            }
        } catch {
            print("Error loading decisions: \(error)")
        }
    }

    // MARK: - Load Single Decision

    func loadDecision(id: String) throws -> Decision? {
        guard let db = db else { return nil }

        let stmt = try db.prepare("SELECT id, title, created_at, resolved_at, chosen_option_id, is_collaborative FROM decisions WHERE id = ?")

        for row in stmt.bind(id) {
            let decisionId = row[0] as? String ?? ""
            let title = row[1] as? String ?? ""
            let createdAtInt = row[2] as? Int64 ?? 0
            let resolvedAtInt = row[3] as? Int64
            let chosenOptionIdStr = row[4] as? String
            let isCollaborativeInt = row[5] as? Int64 ?? 0

            let options = try loadOptions(decisionId: decisionId)
            let chosenOptionId: UUID? = chosenOptionIdStr.flatMap { UUID(uuidString: $0) }
            let resolvedAt: Date? = resolvedAtInt.map { Date(timeIntervalSince1970: TimeInterval($0)) }

            return Decision(
                id: UUID(uuidString: decisionId) ?? UUID(),
                title: title,
                options: options.isEmpty ? [Option(), Option()] : options,
                createdAt: Date(timeIntervalSince1970: TimeInterval(createdAtInt)),
                resolvedAt: resolvedAt,
                chosenOptionId: chosenOptionId,
                isCollaborative: isCollaborativeInt != 0
            )
        }

        return nil
    }

    // MARK: - Load Options

    private func loadOptions(decisionId: String) throws -> [Option] {
        guard let db = db else { return [] }

        var options: [Option] = []

        let stmt = try db.prepare("SELECT id, title, image_url, option_index FROM options WHERE decision_id = ? ORDER BY option_index ASC")

        for row in stmt.bind(decisionId) {
            let optionId = row[0] as? String ?? ""
            let title = row[1] as? String ?? ""
            let imageURL = row[2] as? String

            let pros = try loadProsCons(optionId: optionId, type: .pro)
            let cons = try loadProsCons(optionId: optionId, type: .con)

            let option = Option(
                id: UUID(uuidString: optionId) ?? UUID(),
                title: title,
                imageURL: imageURL,
                pros: pros,
                cons: cons
            )
            options.append(option)
        }

        return options
    }

    // MARK: - Load ProsCons

    private func loadProsCons(optionId: String, type: ProCon.ProConType) throws -> [ProCon] {
        guard let db = db else { return [] }

        var items: [ProCon] = []

        let stmt = try db.prepare("SELECT id, text, weight, added_by FROM pros_cons WHERE option_id = ? AND type = ?")

        for row in stmt.bind(optionId, type.rawValue) {
            let id = row[0] as? String ?? ""
            let text = row[1] as? String ?? ""
            let weightInt = row[2] as? Int64 ?? 1
            let addedBy = row[3] as? String ?? "me"

            let weight = Weight(rawValue: Int(weightInt)) ?? .normal
            let proCon = ProCon(
                id: UUID(uuidString: id) ?? UUID(),
                text: text,
                weight: weight,
                addedBy: addedBy,
                type: type
            )
            items.append(proCon)
        }

        return items
    }

    // MARK: - Save Decision

    func saveDecision(_ decision: Decision) {
        guard let db = db else { return }

        do {
            // Insert or replace decision
            try db.run("""
                INSERT OR REPLACE INTO decisions (id, title, created_at, resolved_at, chosen_option_id, is_collaborative)
                VALUES (?, ?, ?, ?, ?, ?)
            """,
                decision.id.uuidString,
                decision.title,
                Int64(decision.createdAt.timeIntervalSince1970),
                decision.resolvedAt.map { Int64($0.timeIntervalSince1970) },
                decision.chosenOptionId?.uuidString,
                decision.isCollaborative ? 1 : 0
            )

            // Delete existing options for this decision
            try db.run("DELETE FROM options WHERE decision_id = ?", decision.id.uuidString)

            // Save all options with their indices
            for (index, option) in decision.options.enumerated() {
                try saveOption(option, decisionId: decision.id.uuidString, index: index)
            }

            loadDecisions()
        } catch {
            print("Error saving decision: \(error)")
        }
    }

    // MARK: - Save Option

    private func saveOption(_ option: Option, decisionId: String, index: Int) throws {
        guard let db = db else { return }

        // Insert option
        try db.run("""
            INSERT INTO options (id, decision_id, option_index, title, image_url)
            VALUES (?, ?, ?, ?, ?)
        """,
            option.id.uuidString,
            decisionId,
            index,
            option.title,
            option.imageURL
        )

        // Save pros and cons
        for proCon in option.pros {
            try saveProCon(proCon, optionId: option.id.uuidString)
        }
        for proCon in option.cons {
            try saveProCon(proCon, optionId: option.id.uuidString)
        }
    }

    // MARK: - Save ProCon

    private func saveProCon(_ proCon: ProCon, optionId: String) throws {
        guard let db = db else { return }

        try db.run("""
            INSERT INTO pros_cons (id, option_id, type, text, weight, added_by)
            VALUES (?, ?, ?, ?, ?, ?)
        """,
            proCon.id.uuidString,
            optionId,
            proCon.type.rawValue,
            proCon.text,
            proCon.weight.rawValue,
            proCon.addedBy
        )
    }

    // MARK: - Delete Decision

    func deleteDecision(_ decision: Decision) {
        guard let db = db else { return }

        do {
            try db.run("DELETE FROM decisions WHERE id = ?", decision.id.uuidString)
            loadDecisions()
        } catch {
            print("Error deleting decision: \(error)")
        }
    }

    // MARK: - Create New Decision

    func createNewDecision() -> Decision {
        let decision = Decision(
            title: "",
            options: [Option(title: ""), Option(title: "")]
        )
        saveDecision(decision)
        return decision
    }
}
