import Foundation
import SwiftUI

// MARK: - Weight

enum Weight: Int, Codable, CaseIterable {
    case normal = 1
    case bold = 2
    case huge = 3

    func next() -> Weight {
        switch self {
        case .normal: return .bold
        case .bold: return .huge
        case .huge: return .normal
        }
    }
}

// MARK: - ProCon

struct ProCon: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
    var weight: Weight
    var addedBy: String
    let type: ProConType

    enum ProConType: String, Codable {
        case pro
        case con
    }

    init(id: UUID = UUID(), text: String, weight: Weight = .normal, addedBy: String = "me", type: ProConType) {
        self.id = id
        self.text = text
        self.weight = weight
        self.addedBy = addedBy
        self.type = type
    }

    var score: Int {
        let baseScore = weight.rawValue
        return type == .pro ? baseScore : -baseScore
    }
}

// MARK: - Option

struct Option: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var imageURL: String?
    var pros: [ProCon]
    var cons: [ProCon]

    init(id: UUID = UUID(), title: String = "", imageURL: String? = nil, pros: [ProCon] = [], cons: [ProCon] = []) {
        self.id = id
        self.title = title
        self.imageURL = imageURL
        self.pros = pros
        self.cons = cons
    }

    var score: Int {
        let prosScore = pros.reduce(0) { $0 + $1.score }
        let consScore = cons.reduce(0) { $0 + $1.score }
        return prosScore + consScore
    }
}

// MARK: - Outcome Rating

enum OutcomeRating: String, Codable, CaseIterable {
    case great = "great"
    case good = "good"
    case neutral = "neutral"
    case regret = "regret"

    var emoji: String {
        switch self {
        case .great: return "🎉"
        case .good: return "👍"
        case .neutral: return "😐"
        case .regret: return "😔"
        }
    }

    var label: String {
        switch self {
        case .great: return "Great decision!"
        case .good: return "Good choice"
        case .neutral: return "It was okay"
        case .regret: return "I have regrets"
        }
    }

    var color: Color {
        switch self {
        case .great: return .green
        case .good: return .blue
        case .neutral: return .gray
        case .regret: return .orange
        }
    }
}

// MARK: - Decision Outcome

struct DecisionOutcome: Codable, Equatable {
    var rating: OutcomeRating
    var notes: String
    var trackedAt: Date

    init(rating: OutcomeRating, notes: String = "", trackedAt: Date = Date()) {
        self.rating = rating
        self.notes = notes
        self.trackedAt = trackedAt
    }
}

// MARK: - Decision

struct Decision: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var options: [Option]  // Dynamic array of options
    var createdAt: Date
    var resolvedAt: Date?
    var chosenOptionId: UUID?  // ID of chosen option
    var isCollaborative: Bool
    var outcome: DecisionOutcome?  // Outcome tracking (Premium)

    init(
        id: UUID = UUID(),
        title: String = "",
        options: [Option] = [Option(), Option()],  // Default 2 options
        createdAt: Date = Date(),
        resolvedAt: Date? = nil,
        chosenOptionId: UUID? = nil,
        isCollaborative: Bool = false,
        outcome: DecisionOutcome? = nil
    ) {
        self.id = id
        self.title = title
        self.options = options
        self.createdAt = createdAt
        self.resolvedAt = resolvedAt
        self.chosenOptionId = chosenOptionId
        self.isCollaborative = isCollaborative
        self.outcome = outcome
    }

    var isResolved: Bool {
        resolvedAt != nil && chosenOptionId != nil
    }

    var winningOption: Option? {
        guard let chosenId = chosenOptionId else { return nil }
        return options.first { $0.id == chosenId }
    }

    var winningOptionIndex: Int? {
        guard let chosenId = chosenOptionId else { return nil }
        return options.firstIndex { $0.id == chosenId }
    }

    /// Returns the index of the option with highest score, or nil if tied
    var calculatedWinnerIndex: Int? {
        guard !options.isEmpty else { return nil }

        let scores = options.map { $0.score }
        guard let maxScore = scores.max() else { return nil }

        let winningIndices = scores.enumerated().filter { $0.element == maxScore }.map { $0.offset }

        // Return nil if tied between multiple options
        return winningIndices.count == 1 ? winningIndices.first : nil
    }

    var calculatedWinner: Option? {
        guard let index = calculatedWinnerIndex else { return nil }
        return options[index]
    }

    /// True if only one option exists (auto-resolved)
    var isAutoResolved: Bool {
        options.count == 1
    }

    /// True if outcome has been tracked
    var hasOutcome: Bool {
        outcome != nil
    }

    mutating func trackOutcome(rating: OutcomeRating, notes: String = "") {
        self.outcome = DecisionOutcome(rating: rating, notes: notes)
    }

    mutating func resolve(with optionId: UUID) {
        self.chosenOptionId = optionId
        self.resolvedAt = Date()
    }

    mutating func resolve(at index: Int) {
        guard index >= 0 && index < options.count else { return }
        resolve(with: options[index].id)
    }

    mutating func addOption() {
        let newOption = Option(title: "")
        options.append(newOption)
    }

    mutating func removeOption(at index: Int) {
        guard options.count > 1, index >= 0 && index < options.count else { return }
        options.remove(at: index)

        // Auto-resolve if only 1 option left
        if options.count == 1 {
            resolve(with: options[0].id)
        }
    }

    mutating func removeOption(id: UUID) {
        guard let index = options.firstIndex(where: { $0.id == id }) else { return }
        removeOption(at: index)
    }

    /// Get display label for option (A, B, C, ...)
    func optionLabel(at index: Int) -> String {
        guard index >= 0 && index < 26 else { return "\(index + 1)" }
        return String(UnicodeScalar(65 + index)!) // A=65, B=66, etc.
    }
}

// MARK: - Participant (for collaboration)

struct Participant: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var votedForOptionId: UUID?  // Changed from Side to option ID

    init(id: UUID = UUID(), name: String, votedForOptionId: UUID? = nil) {
        self.id = id
        self.name = name
        self.votedForOptionId = votedForOptionId
    }
}

// MARK: - Room (for collaboration)

struct Room: Identifiable, Codable {
    let id: UUID
    let hostName: String
    var participants: [Participant]
    var decision: Decision

    init(id: UUID = UUID(), hostName: String, participants: [Participant] = [], decision: Decision) {
        self.id = id
        self.hostName = hostName
        self.participants = participants
        self.decision = decision
    }
}
