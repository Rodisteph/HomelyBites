import SwiftUI

// ♻️ Évite de répéter le même bloc .alert("Erreur"...) dans chaque View.
//
// AVANT (8x dans le projet) :
//   .alert("Erreur",
//       isPresented: Binding(get: { vm.errorMessage != nil },
//                            set: { if !$0 { vm.errorMessage = nil } }),
//       actions: { Button("OK", role: .cancel) {} },
//       message: { Text(vm.errorMessage ?? "") })
//
// APRÈS :
//   .errorAlert(message: $viewModel.errorMessage)

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
