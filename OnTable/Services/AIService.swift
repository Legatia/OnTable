import Foundation

// MARK: - AI Service

class AIService {
    static let shared = AIService()

    // Backend proxy configuration
    // Production: Vercel deployment
    // For local testing: Change to http://localhost:3000/api/ai/suggestions
    private let backendURL = "https://on-table-be.vercel.app/api/ai/suggestions"

    // Client API Key for backend authentication
    // This key must match CLIENT_API_KEY in your Vercel environment variables
    private let clientAPIKey = "ontable_client_2024_secure_key_prod"

    // MARK: - Rate Limiting (Premium tier)

    private let dailyLimit = 25  // Max requests per day (Premium)
    private let perDecisionLimit = 5  // Max requests per decision (Premium)

    private var dailyRequestCount: Int {
        get { UserDefaults.standard.integer(forKey: "ai_daily_count") }
        set { UserDefaults.standard.set(newValue, forKey: "ai_daily_count") }
    }

    private var lastRequestDate: Date? {
        get { UserDefaults.standard.object(forKey: "ai_last_date") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "ai_last_date") }
    }

    // Track per-decision usage: [decisionId: count]
    private var decisionUsage: [String: Int] {
        get { UserDefaults.standard.dictionary(forKey: "ai_decision_usage") as? [String: Int] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: "ai_decision_usage") }
    }

    private init() {}

    // MARK: - Rate Limit Status

    struct RateLimitStatus {
        let dailyRemaining: Int
        let dailyLimit: Int
        let decisionRemaining: Int
        let decisionLimit: Int
        let canMakeRequest: Bool
        let resetTime: Date?

        var dailyUsed: Int { dailyLimit - dailyRemaining }
        var decisionUsed: Int { decisionLimit - decisionRemaining }
    }

    func getRateLimitStatus(for decisionId: UUID) -> RateLimitStatus {
        resetDailyCountIfNeeded()

        let dailyRemaining = max(0, dailyLimit - dailyRequestCount)
        let decisionCount = decisionUsage[decisionId.uuidString] ?? 0
        let decisionRemaining = max(0, perDecisionLimit - decisionCount)

        let canRequest = dailyRemaining > 0 && decisionRemaining > 0

        // Calculate reset time (next midnight)
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let resetTime = calendar.startOfDay(for: tomorrow)

        return RateLimitStatus(
            dailyRemaining: dailyRemaining,
            dailyLimit: dailyLimit,
            decisionRemaining: decisionRemaining,
            decisionLimit: perDecisionLimit,
            canMakeRequest: canRequest,
            resetTime: resetTime
        )
    }

    private func resetDailyCountIfNeeded() {
        let calendar = Calendar.current

        if let lastDate = lastRequestDate {
            if !calendar.isDateInToday(lastDate) {
                // New day - reset counter
                dailyRequestCount = 0
                // Also clean up old decision usage (older than 7 days could be pruned)
            }
        }
    }

    private func recordRequest(for decisionId: UUID) {
        resetDailyCountIfNeeded()

        // Increment daily count
        dailyRequestCount += 1
        lastRequestDate = Date()

        // Increment decision count
        var usage = decisionUsage
        usage[decisionId.uuidString] = (usage[decisionId.uuidString] ?? 0) + 1
        decisionUsage = usage
    }

    // MARK: - AI Suggestions

    struct AISuggestion: Identifiable {
        let id = UUID()
        let text: String
        let type: SuggestionType

        enum SuggestionType {
            case pro
            case con
        }
    }

    struct AIResponse {
        // Per-option suggestions keyed by label ("A", "B", etc.)
        let optionSuggestions: [String: (pros: [String], cons: [String])]
    }

    func getSuggestions(for decision: Decision) async throws -> AIResponse {
        // Check rate limits
        let status = getRateLimitStatus(for: decision.id)
        guard status.canMakeRequest else {
            if status.dailyRemaining == 0 {
                throw AIError.dailyLimitReached(resetTime: status.resetTime)
            } else {
                throw AIError.decisionLimitReached
            }
        }

        let prompt = buildPrompt(for: decision)
        let response = try await sendRequest(prompt: prompt)

        // Record successful request
        recordRequest(for: decision.id)

        return parseResponse(response)
    }

    // MARK: - Prompt Building

    private func buildPrompt(for decision: Decision) -> String {
        var prompt = """
        You are a decision-making assistant. The user is comparing options and has listed some pros and cons. Your job is to suggest 2-3 additional pros and cons they might have missed for each option.

        Be practical, specific, and helpful. Focus on considerations they likely haven't thought of.

        """

        if !decision.title.isEmpty {
            prompt += "Decision: \(decision.title)\n\n"
        }

        prompt += "Options:\n"

        for (index, option) in decision.options.enumerated() {
            let label = decision.optionLabel(at: index)
            let title = option.title.isEmpty ? "Option \(label)" : option.title

            prompt += "\n\(label). \(title)\n"

            if !option.pros.isEmpty {
                prompt += "Current Pros:\n"
                for pro in option.pros {
                    prompt += "- \(pro.text)\n"
                }
            }

            if !option.cons.isEmpty {
                prompt += "Current Cons:\n"
                for con in option.cons {
                    prompt += "- \(con.text)\n"
                }
            }
        }

        prompt += """

        Respond in this exact JSON format (no markdown, just raw JSON):
        {
            "options": [
                {
                    "label": "A",
                    "suggested_pros": ["pro 1", "pro 2"],
                    "suggested_cons": ["con 1", "con 2"]
                }
            ]
        }

        Keep each suggestion brief (under 10 words). Only suggest things not already listed.
        """

        return prompt
    }

    // MARK: - API Request

    private func sendRequest(prompt: String) async throws -> String {
        guard let url = URL(string: backendURL) else {
            throw AIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(clientAPIKey, forHTTPHeaderField: "x-client-api-key")
        request.timeoutInterval = 30

        // Send prompt to backend
        let body: [String: Any] = [
            "prompt": prompt
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMsg = errorJson["error"] as? String {
                throw AIError.apiError(errorMsg)
            }
            throw AIError.apiError("Backend error (status \(httpResponse.statusCode))")
        }

        // Parse backend response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["text"] as? String else {
            throw AIError.invalidResponse
        }

        return text
    }

    // MARK: - Response Parsing

    private func parseResponse(_ response: String) -> AIResponse {
        // Try to extract JSON from the response
        var jsonString = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove markdown code blocks if present
        if jsonString.hasPrefix("```json") {
            jsonString = String(jsonString.dropFirst(7))
        }
        if jsonString.hasPrefix("```") {
            jsonString = String(jsonString.dropFirst(3))
        }
        if jsonString.hasSuffix("```") {
            jsonString = String(jsonString.dropLast(3))
        }
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let options = json["options"] as? [[String: Any]] else {
            return AIResponse(optionSuggestions: [:])
        }

        var optionSuggestions: [String: (pros: [String], cons: [String])] = [:]

        for option in options {
            let label = option["label"] as? String ?? ""
            let pros = option["suggested_pros"] as? [String] ?? []
            let cons = option["suggested_cons"] as? [String] ?? []

            if !label.isEmpty && (!pros.isEmpty || !cons.isEmpty) {
                optionSuggestions[label] = (pros: pros, cons: cons)
            }
        }

        return AIResponse(optionSuggestions: optionSuggestions)
    }
}

// MARK: - Errors

enum AIError: LocalizedError {
    case notConfigured
    case invalidURL
    case invalidResponse
    case apiError(String)
    case dailyLimitReached(resetTime: Date?)
    case decisionLimitReached

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "AI service unavailable. Please check backend server connection."
        case .invalidURL:
            return "Invalid API URL."
        case .invalidResponse:
            return "Could not parse API response."
        case .apiError(let message):
            return "API error: \(message)"
        case .dailyLimitReached(let resetTime):
            if let reset = resetTime {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                return "Daily AI limit reached. Resets at \(formatter.string(from: reset))."
            }
            return "Daily AI limit reached. Try again tomorrow."
        case .decisionLimitReached:
            return "You've used all AI suggestions for this decision (5 max)."
        }
    }
}

// MARK: - Suggestion Result for UI

struct OptionSuggestions: Identifiable {
    let id = UUID()
    let optionIndex: Int
    let optionLabel: String
    let optionTitle: String
    let suggestedPros: [String]
    let suggestedCons: [String]
}
