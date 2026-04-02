import SwiftUI


struct StackMapView: View {
    let node: StackTreeNode
    
    @State private var isExpanded: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. The Parent Node
            NodeCardView(node: node, isExpanded: isExpanded)
                .onTapGesture {
                    if !node.children.isEmpty {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            isExpanded.toggle()
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            
            // 2. The Children
            if isExpanded && !node.children.isEmpty {
                Rectangle()
                    .fill(node.color.opacity(0.3))
                    .frame(width: 2, height: 15)
                
                HStack(alignment: .top, spacing: 10) {
                    ForEach(node.children) { child in
                        StackMapView(node: child)
                    }
                }
            }
        }
    }
}

// MARK: - Node Visual Component
private struct NodeCardView: View {
    let node: StackTreeNode
    let isExpanded: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: node.isFile ? "doc.fill" : "folder.fill")
                .font(.system(size: node.isFile ? 18 : 26))
                .foregroundColor(node.color)
            
            Text(node.name)
                .font(.system(
                    size: node.isFile ? 9 : 11,
                    weight: node.isFile ? .regular : .bold,
                    design: .rounded
                ))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
                .frame(width: 70)
            
            if !node.children.isEmpty && !isExpanded {
                Image(systemName: "ellipsis")
                    .font(.system(size: 8, weight: .black))
                    .foregroundColor(.gray)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
}
