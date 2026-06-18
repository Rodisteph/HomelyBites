import SwiftUI

extension View {
    func errorAlert(message: Binding<String?>) -> some View {
        alert(
            "Erreur",
            isPresented: Binding(
                get:  { message.wrappedValue != nil },
                set:  { if !$0 { message.wrappedValue = nil } }
            ),
            actions: { Button("OK", role: .cancel) {} },
            message: { Text(message.wrappedValue ?? "") }
        )
    }
}
