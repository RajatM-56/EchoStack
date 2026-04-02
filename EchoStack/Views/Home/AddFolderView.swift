import SwiftUI
import SwiftData


struct AddFolderView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var context
    
    @State private var newFolderName = ""
    @State private var selectedColor: Color? = nil
    
    private let columns = Array(repeating: GridItem(.flexible()), count: 5)
    
    private var isFormValid: Bool {
        !newFolderName.trimmingCharacters(in: .whitespaces).isEmpty && selectedColor != nil
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.98, green: 0.97, blue: 0.95).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        previewSection
                        inputSection
                        colorGridSection
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.top, 20)
                }
            }
            .navigationTitle("New Stack")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(.headline)
                        .foregroundColor(.red)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") { createStack() }
                        .font(.headline)
                        .foregroundColor(isFormValid ? (selectedColor ?? .primary) : .secondary)
                        .disabled(!isFormValid)
                }
            }
        }
    }
}


extension AddFolderView {
    
    // 1. PREVIEW SECTION
    private var previewSection: some View {
        VStack(spacing: 12) {
            Text("PREVIEW")
                .font(.caption2.bold())
                .foregroundColor(.secondary)
            
            BookFolderView(
                title: newFolderName.isEmpty ? "New Subject" : newFolderName,
                itemCount: 0,
                color: selectedColor ?? Color.gray.opacity(0.3)
            )
            .scaleEffect(1.1)
            .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.03), radius: 10)
        )
        .padding(.horizontal)
    }
    
    // 2. INPUT SECTION
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("SUBJECT NAME")
                .font(.caption2.bold())
                .foregroundColor(.secondary)
                .padding(.leading, 5)
            
            TextField("Enter name...", text: $newFolderName)
                .font(.system(.body, design: .serif))
                .padding()
                .background(RoundedRectangle(cornerRadius: 15).fill(Color.white))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                )
        }
        .padding(.horizontal)
    }
    
    // 3. COLOR GRID
    private var colorGridSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("THEME COLOR")
                .font(.caption2.bold())
                .foregroundColor(.secondary)
                .padding(.leading, 5)
            
            LazyVGrid(columns: columns, spacing: 15) {
                ForEach(Self.themeColors, id: \.self) { color in
                    ColorSwatchView(
                        color: color,
                        isSelected: selectedColor == color
                    ) {
                        selectColor(color)
                    }
                }
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 25).fill(Color.white))
        }
        .padding(.horizontal)
    }
}


extension AddFolderView {
    private func selectColor(_ color: Color) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            selectedColor = color
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }
    
    private func createStack() {
        guard let finalColor = selectedColor else { return }
        
        let newStack = SubjectStack(
            title: newFolderName,
            itemCount: 0,
            color: finalColor,
            files: []
        )
        context.insert(newStack)
        dismiss()
    }
}


private struct ColorSwatchView: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 45, height: 45)
            
            if isSelected {
                Circle()
                    .strokeBorder(Color.white, lineWidth: 3)
                    .frame(width: 45, height: 45)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .onTapGesture(perform: action)
    }
}

extension AddFolderView {
    static let themeColors: [Color] = [
        .blue, .teal, .indigo, .orange, .brown, .purple, .green,
        .pink, .red, .yellow, .mint, .cyan, .gray,
        Color(red: 0.4, green: 0.3, blue: 0.6),
        Color(red: 0.1, green: 0.4, blue: 0.3),
        Color(red: 0.8, green: 0.3, blue: 0.3),
        Color(red: 0.2, green: 0.2, blue: 0.3),
        Color(red: 0.6, green: 0.5, blue: 0.2)
    ]
}
