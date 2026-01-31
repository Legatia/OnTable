import SwiftUI

struct TemplatesView: View {
    @EnvironmentObject var databaseService: DatabaseService
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: DecisionTemplate.Category?
    @State private var selectedTemplate: DecisionTemplate?
    @State private var showingDecision = false
    @State private var newDecision: Decision?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Start with a Template")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Choose a template to jumpstart your decision with suggested options and considerations.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    // Categories
                    ForEach(DecisionTemplate.Category.allCases, id: \.self) { category in
                        categorySection(category)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedTemplate) { template in
                TemplatePreviewSheet(template: template) {
                    useTemplate(template)
                }
            }
            .fullScreenCover(isPresented: $showingDecision) {
                if let decision = newDecision {
                    NavigationView {
                        DecisionView(decision: decision)
                            .environmentObject(databaseService)
                    }
                }
            }
        }
    }

    private func categorySection(_ category: DecisionTemplate.Category) -> some View {
        let templates = DecisionTemplate.templates(for: category)
        guard !templates.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                // Category header
                HStack {
                    Image(systemName: category.icon)
                        .foregroundColor(.accentColor)
                    Text(category.rawValue)
                        .font(.headline)
                }
                .padding(.horizontal)

                // Templates horizontal scroll
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(templates) { template in
                            templateCard(template)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        )
    }

    private func templateCard(_ template: DecisionTemplate) -> some View {
        Button(action: { selectedTemplate = template }) {
            VStack(alignment: .leading, spacing: 8) {
                // Icon
                Image(systemName: template.icon)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .frame(width: 40, height: 40)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(10)

                // Name
                Text(template.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Options count
                Text("\(template.options.count) options")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 140, alignment: .leading)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func useTemplate(_ template: DecisionTemplate) {
        let decision = template.toDecision()
        databaseService.saveDecision(decision)
        newDecision = decision
        selectedTemplate = nil
        showingDecision = true
    }
}

// MARK: - Template Preview Sheet

struct TemplatePreviewSheet: View {
    let template: DecisionTemplate
    let onUse: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack {
                        Image(systemName: template.icon)
                            .font(.title)
                            .foregroundColor(.accentColor)
                            .frame(width: 60, height: 60)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(16)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name)
                                .font(.title3)
                                .fontWeight(.bold)

                            Text(template.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)

                    // Options preview
                    Text("Included Options")
                        .font(.headline)

                    ForEach(Array(template.options.enumerated()), id: \.offset) { index, option in
                        optionPreview(option, index: index)
                    }

                    // Use button
                    Button(action: onUse) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Use This Template")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .cornerRadius(12)
                    }
                    .padding(.top)
                }
                .padding()
            }
            .navigationTitle("Template Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func optionPreview(_ option: DecisionTemplate.TemplateOption, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Option title
            HStack {
                Text(String(Character(UnicodeScalar(65 + index)!)))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.accentColor)
                    .cornerRadius(6)

                Text(option.title)
                    .font(.headline)
            }

            // Suggested pros
            if !option.suggestedPros.filter({ !$0.isEmpty }).isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Suggested Pros", systemImage: "hand.thumbsup.fill")
                        .font(.caption)
                        .foregroundColor(.green)

                    ForEach(option.suggestedPros.filter { !$0.isEmpty }, id: \.self) { pro in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.green.opacity(0.3))
                                .frame(width: 6, height: 6)
                            Text(pro)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // Suggested cons
            if !option.suggestedCons.filter({ !$0.isEmpty }).isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Suggested Cons", systemImage: "hand.thumbsdown.fill")
                        .font(.caption)
                        .foregroundColor(.red)

                    ForEach(option.suggestedCons.filter { !$0.isEmpty }, id: \.self) { con in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.red.opacity(0.3))
                                .frame(width: 6, height: 6)
                            Text(con)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Preview

struct TemplatesView_Previews: PreviewProvider {
    static var previews: some View {
        TemplatesView()
            .environmentObject(DatabaseService.shared)
    }
}
