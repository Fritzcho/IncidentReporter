import SwiftUI

/// Reusable form input fields for configuring a trusted emergency contact ("Guardian") name and phone number.
struct EmergencyContactInputView: View {
    @Binding var contactName: String
    @Binding var contactPhone: String

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "person.badge.shield.checkmark.fill")
                    .foregroundStyle(.teal)
                    .frame(width: 24)

                TextField("Trusted Contact Name (e.g. Emma)", text: $contactName)
                    .textContentType(.name)
            }

            Divider()

            HStack(spacing: 10) {
                Image(systemName: "phone.arrow.up.right.fill")
                    .foregroundStyle(.teal)
                    .frame(width: 24)

                TextField("Emergency Phone (+46 70 123 45 67)", text: $contactPhone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    Form {
        Section("Trusted Guardian Contact") {
            EmergencyContactInputView(
                contactName: .constant("Emma"),
                contactPhone: .constant("+46 70 123 45 67")
            )
        }
    }
}
