import SwiftUI

struct MoveFileSheet: View {
    @Environment(\.dismiss) var dismiss
    
    var allStacks: [SubjectStack] 
    
    let currentStackID: UUID
    let fileName: String
    var onSelect: (UUID) -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.98, green: 0.97, blue: 0.95).ignoresSafeArea()
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 20) {
                        ForEach(allStacks) { stack in
                            if stack.id != currentStackID {
                                Button(action: { onSelect(stack.id) }) {
                                    BookFolderView(title: stack.title, itemCount: stack.itemCount, color: stack.color.swiftUIColor)
                                        .scaleEffect(0.8)
                                }.buttonStyle(PlainButtonStyle())
                            }
                        }
                    }.padding()
                }
            }
            .navigationTitle("Move to...")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}
