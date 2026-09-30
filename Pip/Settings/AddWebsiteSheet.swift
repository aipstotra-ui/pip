import SwiftUI

/// Small sheet for adding a website: a name and an https address.
struct AddWebsiteSheet: View {
    let store: TargetStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var address = ""
    @State private var message: String?
    @FocusState private var focus: Field?

    private enum Field { case name, address }

    private var canAdd: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !address.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add a website")
                .font(.headline)
            Form {
                TextField("Name", text: $name, prompt: Text("Perplexity"))
                    .focused($focus, equals: .name)
                    .accessibilityLabel("Website name")
                TextField("Address", text: $address, prompt: Text("https://example.com"))
                    .focused($focus, equals: .address)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                    .accessibilityLabel("Website address")
            }
            .onSubmit(add)
            Text(verbatim: message ?? "Only https:// addresses are supported.")
                .font(.caption)
                .foregroundStyle(message == nil ? Color.secondary : Color.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(Text(verbatim: message ?? "Only https addresses are supported."))
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add", action: add)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canAdd)
            }
        }
        .padding(20)
        .frame(width: 380)
        .onAppear { focus = .name }
        .onChange(of: name) { message = nil }
        .onChange(of: address) { message = nil }
    }

    private func add() {
        guard canAdd else { return }
        do {
            try store.addWebsite(name: name, address: address)
            dismiss()
        } catch {
            message = error.localizedDescription
        }
    }
}
