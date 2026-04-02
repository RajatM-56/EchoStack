import SwiftUI

struct AddFilePopUp: View {
    @Environment(\.dismiss) var dismiss
    let stackColor: Color
    let isLink: Bool
    let initialName: String
    var onAdd: (String, String) -> Void
    
    @State private var displayName: String
    @State private var urlString: String

    init(stackColor: Color, isLink: Bool, initialName: String, onAdd: @escaping (String, String) -> Void) {
        self.stackColor = stackColor
        self.isLink = isLink
        self.initialName = initialName
        self.onAdd = onAdd
        _displayName = State(initialValue: isLink ? "" : initialName)
        _urlString = State(initialValue: isLink ? "https://" : "")
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text(isLink ? "Add Web Link" : "Rename File")
                .font(.headline)
                .padding(.top)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Display Name").font(.caption).foregroundColor(.secondary)
                TextField("e.g. Research Paper", text: $displayName)
                    .padding()
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(10)
                
                if isLink {
                    Text("URL").font(.caption).foregroundColor(.secondary)
                    TextField("https://...", text: $urlString)
                        .padding()
                        .background(Color.black.opacity(0.05))
                        .cornerRadius(10)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }
            }
            .padding(.horizontal)
            
            Button(action: {
                onAdd(displayName, isLink ? urlString : "")
                dismiss()
            }) {
                Text("Confirm")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(stackColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .disabled(displayName.isEmpty || (isLink && urlString.count < 10))
            
            Spacer()
        }
        .padding()
    }
}
