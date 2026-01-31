import Foundation

struct DecisionTemplate: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let category: Category
    let description: String
    let options: [TemplateOption]

    struct TemplateOption {
        let title: String
        let suggestedPros: [String]
        let suggestedCons: [String]
    }

    enum Category: String, CaseIterable {
        case career = "Career"
        case purchases = "Purchases"
        case lifestyle = "Lifestyle"
        case relationships = "Relationships"
        case travel = "Travel"
        case education = "Education"

        var icon: String {
            switch self {
            case .career: return "briefcase.fill"
            case .purchases: return "cart.fill"
            case .lifestyle: return "heart.fill"
            case .relationships: return "person.2.fill"
            case .travel: return "airplane"
            case .education: return "graduationcap.fill"
            }
        }
    }

    func toDecision() -> Decision {
        let decisionOptions = options.map { templateOption in
            Option(
                title: templateOption.title,
                pros: templateOption.suggestedPros.map { ProCon(text: $0, type: .pro) },
                cons: templateOption.suggestedCons.map { ProCon(text: $0, type: .con) }
            )
        }
        return Decision(title: name, options: decisionOptions)
    }
}

// MARK: - Built-in Templates

extension DecisionTemplate {
    static let allTemplates: [DecisionTemplate] = [
        // Career
        DecisionTemplate(
            name: "Job Offer Comparison",
            icon: "briefcase.fill",
            category: .career,
            description: "Compare multiple job offers",
            options: [
                TemplateOption(
                    title: "Current Job",
                    suggestedPros: ["Familiar environment", "Established relationships"],
                    suggestedCons: ["Limited growth", "Known frustrations"]
                ),
                TemplateOption(
                    title: "New Opportunity",
                    suggestedPros: ["Fresh start", "New challenges"],
                    suggestedCons: ["Unknown culture", "Proving yourself again"]
                )
            ]
        ),
        DecisionTemplate(
            name: "Career Change",
            icon: "arrow.triangle.2.circlepath",
            category: .career,
            description: "Should you switch careers?",
            options: [
                TemplateOption(
                    title: "Stay in Current Field",
                    suggestedPros: ["Expertise built up", "Industry connections"],
                    suggestedCons: ["Burnout risk", "Limited passion"]
                ),
                TemplateOption(
                    title: "Switch Careers",
                    suggestedPros: ["Follow passion", "New energy"],
                    suggestedCons: ["Starting over", "Income uncertainty"]
                )
            ]
        ),

        // Purchases
        DecisionTemplate(
            name: "Big Purchase",
            icon: "dollarsign.circle.fill",
            category: .purchases,
            description: "Evaluate a major purchase decision",
            options: [
                TemplateOption(
                    title: "Buy Now",
                    suggestedPros: ["Immediate benefit", "Current pricing"],
                    suggestedCons: ["Financial impact", "Buyer's remorse risk"]
                ),
                TemplateOption(
                    title: "Wait",
                    suggestedPros: ["Save more money", "Better deal later"],
                    suggestedCons: ["Delayed gratification", "Price might increase"]
                )
            ]
        ),
        DecisionTemplate(
            name: "Rent vs Buy Home",
            icon: "house.fill",
            category: .purchases,
            description: "Housing decision analysis",
            options: [
                TemplateOption(
                    title: "Rent",
                    suggestedPros: ["Flexibility", "No maintenance costs", "Lower upfront"],
                    suggestedCons: ["No equity", "Rent increases", "Less control"]
                ),
                TemplateOption(
                    title: "Buy",
                    suggestedPros: ["Build equity", "Stability", "Tax benefits"],
                    suggestedCons: ["Large down payment", "Maintenance responsibility", "Less flexibility"]
                )
            ]
        ),
        DecisionTemplate(
            name: "New Phone",
            icon: "iphone",
            category: .purchases,
            description: "Compare smartphone options",
            options: [
                TemplateOption(
                    title: "iPhone",
                    suggestedPros: ["Ecosystem integration", "Long software support"],
                    suggestedCons: ["Higher price", "Less customization"]
                ),
                TemplateOption(
                    title: "Android",
                    suggestedPros: ["More choices", "Customization"],
                    suggestedCons: ["Fragmented updates", "Varying quality"]
                )
            ]
        ),

        // Lifestyle
        DecisionTemplate(
            name: "City vs Suburbs",
            icon: "building.2.fill",
            category: .lifestyle,
            description: "Where should you live?",
            options: [
                TemplateOption(
                    title: "City Living",
                    suggestedPros: ["Walkability", "Culture & dining", "Career opportunities"],
                    suggestedCons: ["Higher cost", "Noise", "Less space"]
                ),
                TemplateOption(
                    title: "Suburbs",
                    suggestedPros: ["More space", "Quieter", "Better schools"],
                    suggestedCons: ["Car dependent", "Less diversity", "Longer commute"]
                )
            ]
        ),
        DecisionTemplate(
            name: "Health Decision",
            icon: "heart.text.square.fill",
            category: .lifestyle,
            description: "Evaluate health-related choices",
            options: [
                TemplateOption(
                    title: "Option A",
                    suggestedPros: [""],
                    suggestedCons: [""]
                ),
                TemplateOption(
                    title: "Option B",
                    suggestedPros: [""],
                    suggestedCons: [""]
                )
            ]
        ),

        // Relationships
        DecisionTemplate(
            name: "Relationship Crossroads",
            icon: "heart.fill",
            category: .relationships,
            description: "Navigate a relationship decision",
            options: [
                TemplateOption(
                    title: "Stay Together",
                    suggestedPros: ["History together", "Known compatibility"],
                    suggestedCons: ["Existing issues", "Comfort vs growth"]
                ),
                TemplateOption(
                    title: "Move On",
                    suggestedPros: ["Fresh start", "Personal growth"],
                    suggestedCons: ["Emotional difficulty", "Uncertainty"]
                )
            ]
        ),

        // Travel
        DecisionTemplate(
            name: "Vacation Planning",
            icon: "airplane",
            category: .travel,
            description: "Choose between destinations",
            options: [
                TemplateOption(
                    title: "Beach Destination",
                    suggestedPros: ["Relaxation", "Warm weather"],
                    suggestedCons: ["Can be crowded", "Less adventure"]
                ),
                TemplateOption(
                    title: "City Trip",
                    suggestedPros: ["Culture", "Sightseeing"],
                    suggestedCons: ["More tiring", "Expensive"]
                )
            ]
        ),

        // Education
        DecisionTemplate(
            name: "Grad School",
            icon: "graduationcap.fill",
            category: .education,
            description: "Should you pursue graduate education?",
            options: [
                TemplateOption(
                    title: "Get Degree",
                    suggestedPros: ["Career advancement", "Deeper knowledge"],
                    suggestedCons: ["Time investment", "Student debt"]
                ),
                TemplateOption(
                    title: "Skip It",
                    suggestedPros: ["Start earning sooner", "Real-world experience"],
                    suggestedCons: ["May limit options", "Miss networking"]
                )
            ]
        ),
        DecisionTemplate(
            name: "Online vs In-Person Learning",
            icon: "laptopcomputer",
            category: .education,
            description: "Choose your learning format",
            options: [
                TemplateOption(
                    title: "Online",
                    suggestedPros: ["Flexibility", "Lower cost", "Self-paced"],
                    suggestedCons: ["Less interaction", "Self-discipline needed"]
                ),
                TemplateOption(
                    title: "In-Person",
                    suggestedPros: ["Direct interaction", "Structured", "Networking"],
                    suggestedCons: ["Less flexible", "Commute required"]
                )
            ]
        )
    ]

    static func templates(for category: Category) -> [DecisionTemplate] {
        allTemplates.filter { $0.category == category }
    }
}
