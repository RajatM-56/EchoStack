import SwiftUI
import FoundationModels


// MARK: - Auto Mind Map View

@available(iOS 26.0, *)
struct AutoMindMapView: View {
    let stack: SubjectStack
    let allStacks: [SubjectStack]
    let singleFileName: String?
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var layoutNodes: [LayoutNode] = []
    @State private var layoutEdges: [LayoutEdge] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var canvasSize: CGSize = CGSize(width: 800, height: 600)
    
    // Zoom
    @State private var currentScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    let paperBackground = Color(red: 0.98, green: 0.97, blue: 0.95)
    let inkColor = Color(red: 0.1, green: 0.1, blue: 0.15)
    
    var stackColor: Color { stack.color.swiftUIColor }
    
    init(stack: SubjectStack, allStacks: [SubjectStack]) {
        self.stack = stack
        self.allStacks = allStacks
        self.singleFileName = nil
    }
    
    init(stack: SubjectStack, allStacks: [SubjectStack], fileName: String) {
        self.stack = stack
        self.allStacks = allStacks
        self.singleFileName = fileName
    }
    
    private var displayTitle: String {
        if let name = singleFileName {
            return (name as NSString).deletingPathExtension
        }
        return stack.title
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider().background(stackColor.opacity(0.3))
            
            ZStack {
                paperBackground
                
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if layoutNodes.isEmpty {
                    emptyView
                } else {
                    mindMapContent
                }
            }
        }
        .background(paperBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .task { await generateMindMap() }
    }
    
    
    // MARK: - Mind Map Content
    
    private var mindMapContent: some View {
        ZStack(alignment: .bottom) {
            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                MindMapCanvasView(
                    nodes: layoutNodes,
                    edges: layoutEdges,
                    accentColor: stackColor,
                    inkColor: inkColor
                )
                .frame(
                    width: canvasSize.width * currentScale,
                    height: canvasSize.height * currentScale
                )
                .scaleEffect(currentScale, anchor: .center)
                .padding(40)
            }
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        let newScale = lastScale * value.magnification
                        currentScale = min(max(newScale, 0.3), 3.0)
                    }
                    .onEnded { _ in
                        lastScale = currentScale
                    }
            )
            
            // Zoom controls
            zoomControls
        }
    }
    
    private var zoomControls: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    currentScale = max(0.3, currentScale - 0.2)
                    lastScale = currentScale
                }
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(stackColor)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            
            Text("\(Int(currentScale * 100))%")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .frame(width: 44)
            
            Button {
                withAnimation(.spring(response: 0.3)) {
                    currentScale = min(3.0, currentScale + 0.2)
                    lastScale = currentScale
                }
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(stackColor)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            
            Button {
                withAnimation(.spring(response: 0.4)) {
                    currentScale = 1.0
                    lastScale = 1.0
                }
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(stackColor)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(.ultraThinMaterial))
            }
        }
        .padding(10)
        .background(
            Capsule().fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        )
        .padding(.bottom, 16)
    }
    
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(stackColor)
            }
            .contentShape(Rectangle())
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("Mind Map")
                    .font(.system(.headline, design: .serif))
                    .foregroundColor(inkColor)
                
                Text(displayTitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if !layoutNodes.isEmpty {
                let topicCount = layoutNodes.count
                Text("\(topicCount) topics")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(stackColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(stackColor.opacity(0.1)))
            } else {
                Color.clear.frame(width: 70)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(paperBackground)
    }
    
    
    // MARK: - States
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .stroke(stackColor.opacity(0.2), lineWidth: 3)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(stackColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .modifier(MindMapSpinModifier())
                
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 22))
                    .foregroundColor(stackColor)
            }
            
            VStack(spacing: 8) {
                Text("Building Your Mind Map")
                    .font(.system(.headline, design: .serif))
                    .foregroundColor(inkColor)
                
                Text("Analyzing documents and organizing key concepts...")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange.opacity(0.5))
            
            Text(message)
                .font(.system(size: 14, design: .serif))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Try Again") { Task { await generateMindMap() } }
                .font(.system(.subheadline, design: .serif).bold())
                .foregroundColor(stackColor)
            
            Spacer()
        }
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary.opacity(0.3))
            
            Text("No topics found")
                .font(.system(.headline, design: .serif))
                .foregroundColor(inkColor)
            
            Text("Add documents with more text content to generate a mind map.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    
    // MARK: - Generation Pipeline
    
    private func generateMindMap() async {
        isLoading = true
        errorMessage = nil
        
        // 1. Check model availability
        let model = SystemLanguageModel.default
        guard model.availability == .available else {
            errorMessage = "Apple Intelligence is not available on this device. Please ensure it is enabled in Settings."
            isLoading = false
            return
        }
        
        // 2. Extract text
        let text = MindMapEngine.extractText(
            from: stack,
            allStacks: allStacks,
            singleFileName: singleFileName
        )
        
        guard text.count > 50 else {
            errorMessage = "Not enough text content to generate a mind map. Add more documents."
            isLoading = false
            return
        }
        
        // 3. Generate via LLM
        do {
            let rootTopic = try await MindMapEngine.generateMindMap(
                rootTitle: displayTitle,
                documentText: text
            )
            
            // 4. Layout
            let (nodes, edges, size) = MindMapEngine.layoutTree(rootTopic)
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                layoutNodes = nodes
                layoutEdges = edges
                canvasSize = size
                isLoading = false
            }
        } catch {
            errorMessage = "Failed to generate mind map: \(error.localizedDescription)"
            isLoading = false
        }
    }
}


// MARK: - Mind Map Canvas

struct MindMapCanvasView: View {
    let nodes: [LayoutNode]
    let edges: [LayoutEdge]
    let accentColor: Color
    let inkColor: Color
    
    var body: some View {
        ZStack {
            // Layer 1: Branch connections
            Canvas { context, size in
                let nodePositions: [UUID: LayoutNode] = Dictionary(
                    uniqueKeysWithValues: nodes.map { ($0.id, $0) }
                )
                
                for edge in edges {
                    guard let fromNode = nodePositions[edge.fromID],
                          let toNode = nodePositions[edge.toID] else { continue }
                    
                    let from = fromNode.position
                    let to = toNode.position
                    
                    // Cubic Bézier — exits right side of parent, enters left side of child
                    let startX = from.x + fromNode.size.width / 2
                    let startY = from.y
                    let endX = to.x - toNode.size.width / 2
                    let endY = to.y
                    
                    let controlOffset = (endX - startX) * 0.5
                    
                    var path = Path()
                    path.move(to: CGPoint(x: startX, y: startY))
                    path.addCurve(
                        to: CGPoint(x: endX, y: endY),
                        control1: CGPoint(x: startX + controlOffset, y: startY),
                        control2: CGPoint(x: endX - controlOffset, y: endY)
                    )
                    
                    let depthOpacity = max(0.12, 0.3 - Double(edge.depth) * 0.06)
                    let lineWidth: CGFloat = edge.depth == 1 ? 2.5 : 1.8
                    
                    context.stroke(
                        path,
                        with: .color(accentColor.opacity(depthOpacity)),
                        lineWidth: lineWidth
                    )
                }
            }
            
            // Layer 2: Node cards
            ForEach(nodes) { node in
                MindMapNodeCard(
                    node: node,
                    accentColor: accentColor,
                    inkColor: inkColor
                )
                .position(node.position)
            }
        }
    }
}


// MARK: - Node Card

struct MindMapNodeCard: View {
    let node: LayoutNode
    let accentColor: Color
    let inkColor: Color
    
    private var isRoot: Bool { node.depth == 0 }
    private var isBranch: Bool { node.depth == 1 }
    
    private var backgroundColor: Color {
        if isRoot { return accentColor }
        if isBranch { return accentColor.opacity(0.1) }
        return Color.white
    }
    
    private var titleColor: Color {
        if isRoot { return .white }
        return inkColor
    }
    
    private var summaryColor: Color {
        if isRoot { return .white.opacity(0.85) }
        return .secondary
    }
    
    private var borderColor: Color {
        if isRoot { return .clear }
        if isBranch { return accentColor.opacity(0.3) }
        return Color.black.opacity(0.06)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(node.topic.title)
                .font(.system(
                    size: isRoot ? 15 : (isBranch ? 13 : 11.5),
                    weight: isRoot ? .bold : .semibold,
                    design: .serif
                ))
                .foregroundColor(titleColor)
                .lineLimit(2)
            
            Text(node.topic.summary)
                .font(.system(
                    size: isRoot ? 11 : (isBranch ? 10.5 : 10),
                    weight: .regular,
                    design: .serif
                ))
                .foregroundColor(summaryColor)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, isRoot ? 16 : 12)
        .padding(.vertical, isRoot ? 12 : 9)
        .frame(width: node.size.width, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: isRoot ? 16 : 12)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: isRoot ? 16 : 12)
                        .stroke(borderColor, lineWidth: isRoot ? 0 : 1)
                )
                .shadow(
                    color: isRoot
                        ? accentColor.opacity(0.25)
                        : Color.black.opacity(0.05),
                    radius: isRoot ? 10 : 5,
                    y: isRoot ? 4 : 2
                )
        )
    }
}


// MARK: - Spin Animation Modifier

private struct MindMapSpinModifier: ViewModifier {
    @State private var rotation: Double = 0
    
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}
