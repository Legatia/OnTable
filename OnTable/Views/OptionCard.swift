import SwiftUI

struct OptionCard: View {
    @Binding var option: Option
    let optionLabel: String  // "A", "B", "C", etc.
    let canDelete: Bool
    let onDelete: (() -> Void)?

    @State private var newProText = ""
    @State private var newConText = ""
    @State private var isAddingPro = false
    @State private var isAddingCon = false
    @FocusState private var focusedField: Field?

    enum Field {
        case title, pro, con
    }

    init(option: Binding<Option>, optionLabel: String, canDelete: Bool = true, onDelete: (() -> Void)? = nil) {
        self._option = option
        self.optionLabel = optionLabel
        self.canDelete = canDelete
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with title and delete button
            HStack {
                // Title
                TextField("Option \(optionLabel)", text: $option.title)
                    .font(Font.title3.weight(.semibold))
                    .textFieldStyle(.plain)

                Spacer()

                // Delete button
                if canDelete, let onDelete = onDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red.opacity(0.7))
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .focused($focusedField, equals: .title)

            // Score badge
            HStack {
                Spacer()
                Text("Score: \(option.score)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(scoreColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(scoreColor.opacity(0.1))
                    .cornerRadius(12)
            }

            // Pros Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Pros", systemImage: "hand.thumbsup.fill")
                        .font(Font.subheadline.weight(.medium))
                        .foregroundColor(.green)

                    Spacer()

                    Button(action: { startAddingPro() }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.green)
                    }
                }

                // Pro items
                ForEach(option.pros) { pro in
                    ProConRow(
                        proCon: pro,
                        onWeightChange: { cycleWeight(for: pro) },
                        onDelete: { deletePro(pro) }
                    )
                }

                // Add pro field
                if isAddingPro {
                    HStack {
                        TextField("Add a pro...", text: $newProText)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                            .focused($focusedField, equals: .pro)
                            .onSubmit { submitPro() }

                        Button(action: submitPro) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                        .disabled(newProText.isEmpty)

                        Button(action: cancelAddingPro) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Divider()

            // Cons Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Cons", systemImage: "hand.thumbsdown.fill")
                        .font(Font.subheadline.weight(.medium))
                        .foregroundColor(.red)

                    Spacer()

                    Button(action: { startAddingCon() }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.red)
                    }
                }

                // Con items
                ForEach(option.cons) { con in
                    ProConRow(
                        proCon: con,
                        onWeightChange: { cycleWeight(for: con) },
                        onDelete: { deleteCon(con) }
                    )
                }

                // Add con field
                if isAddingCon {
                    HStack {
                        TextField("Add a con...", text: $newConText)
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                            .focused($focusedField, equals: .con)
                            .onSubmit { submitCon() }

                        Button(action: submitCon) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.red)
                        }
                        .disabled(newConText.isEmpty)

                        Button(action: cancelAddingCon) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - Score Color

    private var scoreColor: Color {
        if option.score > 0 {
            return .green
        } else if option.score < 0 {
            return .red
        } else {
            return .secondary
        }
    }

    // MARK: - Pro Actions

    private func startAddingPro() {
        isAddingPro = true
        isAddingCon = false
        focusedField = .pro
    }

    private func submitPro() {
        guard !newProText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let pro = ProCon(text: newProText.trimmingCharacters(in: .whitespaces), type: .pro)
        option.pros.append(pro)
        newProText = ""
        isAddingPro = false
    }

    private func cancelAddingPro() {
        newProText = ""
        isAddingPro = false
    }

    private func deletePro(_ pro: ProCon) {
        option.pros.removeAll { $0.id == pro.id }
    }

    // MARK: - Con Actions

    private func startAddingCon() {
        isAddingCon = true
        isAddingPro = false
        focusedField = .con
    }

    private func submitCon() {
        guard !newConText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let con = ProCon(text: newConText.trimmingCharacters(in: .whitespaces), type: .con)
        option.cons.append(con)
        newConText = ""
        isAddingCon = false
    }

    private func cancelAddingCon() {
        newConText = ""
        isAddingCon = false
    }

    private func deleteCon(_ con: ProCon) {
        option.cons.removeAll { $0.id == con.id }
    }

    // MARK: - Weight Cycling

    private func cycleWeight(for proCon: ProCon) {
        if let index = option.pros.firstIndex(where: { $0.id == proCon.id }) {
            option.pros[index].weight = option.pros[index].weight.next()
        } else if let index = option.cons.firstIndex(where: { $0.id == proCon.id }) {
            option.cons[index].weight = option.cons[index].weight.next()
        }
    }
}

// MARK: - Preview

struct OptionCard_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 12) {
            OptionCard(
                option: .constant(Option(
                    title: "iPhone 15",
                    pros: [
                        ProCon(text: "Great camera", weight: .bold, type: .pro),
                        ProCon(text: "iOS ecosystem", type: .pro)
                    ],
                    cons: [
                        ProCon(text: "Expensive", weight: .huge, type: .con)
                    ]
                )),
                optionLabel: "A",
                canDelete: true,
                onDelete: {}
            )

            OptionCard(
                option: .constant(Option(
                    title: "Samsung S24",
                    pros: [
                        ProCon(text: "Better display", type: .pro),
                        ProCon(text: "More customizable", type: .pro)
                    ],
                    cons: [
                        ProCon(text: "Less reliable updates", type: .con)
                    ]
                )),
                optionLabel: "B",
                canDelete: false,
                onDelete: nil
            )
        }
        .padding()
        .background(Color(.systemGray6))
    }
}
