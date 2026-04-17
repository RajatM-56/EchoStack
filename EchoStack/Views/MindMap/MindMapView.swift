import SwiftUI
import PDFKit


// MARK: - Mind Map Canvas View

struct MindMapCanvasView: View {
    let nodes: [MindMapNode]
    let edges: [MindMapEdge]
    let accentColor: Color
    
    let inkColor = Color(red: 0.1, green: 0.1, blue: 0.15)
    
    var body: some View {
        ZStack {
            // Layer 1: Edges
            Canvas { context, size in
                let nodePositions: [UUID: CGPoint] = Dictionary(
                    uniqueKeysWithValues: nodes.map { ($0.id, $0.position) }
                )
                
                for edge in edges {
                    guard let from = nodePositions[edge.from],
                          let to = nodePositions[edge.to] else { continue }
                    
                    var path = Path()
                    let midX = (from.x + to.x) / 2
                    let midY = (from.y + to.y) / 2
                    let dx = to.x - from.x
                    let dy = to.y - from.y
                    let controlOffset: CGFloat = min(abs(dx), abs(dy)) * 0.3
                    let controlPoint = CGPoint(
                        x: midX + controlOffset * (dy > 0 ? -1 : 1),
                        y: midY + controlOffset * (dx > 0 ? 1 : -1)
                    )
                    
                    path.move(to: from)
                    path.addQuadCurve(to: to, control: controlPoint)
                    
                    let lineWidth = max(1, min(CGFloat(edge.weight), 3))
                    context.stroke(
                        path,
                        with: .color(accentColor.opacity(0.25)),
                        lineWidth: lineWidth
                    )
                }
            }
            
            // Layer 2: Nodes
            ForEach(nodes) { node in
                NodeBubbleView(
                    node: node,
                    accentColor: accentColor,
                    inkColor: inkColor,
                    isCenter: node.id == nodes.first?.id
                )
                .position(node.position)
            }
        }
    }
}


// MARK: - Node Bubble

struct NodeBubbleView: View {
    let node: MindMapNode
    let accentColor: Color
    let inkColor: Color
    let isCenter: Bool
    
    var body: some View {
        Text(node.title)
            .font(.system(
                size: isCenter ? 14 : max(10, 12 * node.relevance),
                weight: isCenter ? .bold : .semibold,
                design: .serif
            ))
            .foregroundColor(isCenter ? .white : inkColor)
            .padding(.horizontal, isCenter ? 16 : 12)
            .padding(.vertical, isCenter ? 10 : 7)
            .background(
                Group {
                    if isCenter {
                        Capsule()
                            .fill(accentColor)
                            .shadow(color: accentColor.opacity(0.3), radius: 8, y: 3)
                    } else {
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.06), radius: 5, y: 2)
                            .overlay(
                                Capsule()
                                    .stroke(accentColor.opacity(0.2), lineWidth: 1)
                            )
                    }
                }
            )
            .fixedSize()
    }
}


// MARK: - Auto Mind Map View

struct AutoMindMapView: View {
    let stack: SubjectStack
    let allStacks: [SubjectStack]
    let singleFileName: String?
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var nodes: [MindMapNode] = []
    @State private var edges: [MindMapEdge] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var canvasSize: CGSize = CGSize(width: 400, height: 500)
    
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
            // HEADER — always visible, above everything
            headerView
            Divider().background(stackColor.opacity(0.3))
            
            // CONTENT
            ZStack {
                paperBackground
                
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error)
                } else if nodes.isEmpty {
                    emptyView
                } else {
                    mindMapContent
                }
            }
        }
        .background(paperBackground.ignoresSafeArea())
        .navigationBarHidden(true)
        .task { await generateMindMap() }
    }
    
    // MARK: - Mind Map Content
    
    private var mindMapContent: some View {
        ZStack(alignment: .bottom) {
            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                MindMapCanvasView(
                    nodes: nodes,
                    edges: edges,
                    accentColor: stackColor
                )
                .frame(width: canvasSize.width * currentScale, height: canvasSize.height * currentScale)
                .scaleEffect(currentScale, anchor: .center)
                .padding(40)
            }
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        let newScale = lastScale * value.magnification
                        currentScale = min(max(newScale, 0.4), 3.0)
                    }
                    .onEnded { _ in
                        lastScale = currentScale
                    }
            )
            
            // Zoom controls
            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        currentScale = max(0.4, currentScale - 0.2)
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
            
            if !nodes.isEmpty {
                Text("\(nodes.count) topics")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(stackColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(stackColor.opacity(0.1)))
            } else {
                // Invisible spacer to balance the header
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
                Text("Mapping Your Knowledge")
                    .font(.system(.headline, design: .serif))
                    .foregroundColor(inkColor)
                
                Text("Extracting key topics and relationships...")
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
        
        let fileContents: [(fileName: String, text: String)]
        
        if let fileName = singleFileName {
            let text = extractFileContent(fileName: fileName)
            fileContents = [(fileName: fileName, text: text)]
        } else {
            fileContents = extractAllFileContents()
        }
        
        let allText = fileContents.map(\.text).joined(separator: "\n\n")
        
        guard allText.count > 50 else {
            errorMessage = "Not enough text content to generate a mind map."
            isLoading = false
            return
        }
        
        let keywordsWithContext = MindMapEngine.extractKeywordsWithContext(
            from: fileContents,
            maxCount: 20
        )
        
        guard keywordsWithContext.count >= 2 else {
            errorMessage = "Could not extract enough distinct topics. Try adding more content."
            isLoading = false
            return
        }
        
        let nodeCount = keywordsWithContext.count
        let dimension = max(500, CGFloat(nodeCount) * 60)
        canvasSize = CGSize(width: dimension, height: dimension)
        
        let generatedNodes = MindMapEngine.generateNodePositions(
            from: keywordsWithContext,
            canvasSize: canvasSize
        )
        
        let generatedEdges = MindMapEngine.generateEdges(
            keywords: keywordsWithContext.map(\.keyword),
            text: allText,
            nodes: generatedNodes
        )
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            nodes = generatedNodes
            edges = generatedEdges
            isLoading = false
        }
    }
    
    // MARK: - Text Extraction
    
    private func extractAllFileContents() -> [(fileName: String, text: String)] {
        var results: [(fileName: String, text: String)] = []
        
        for item in stack.files {
            switch item {
            case .file(_, let fileName):
                if !fileName.contains("|") {
                    let content = extractFileContent(fileName: fileName)
                    if !content.isEmpty {
                        results.append((fileName: fileName, text: content))
                    }
                }
            case .folder(let subID):
                if let sub = allStacks.first(where: { $0.id == subID }) {
                    for subItem in sub.files {
                        if case .file(_, let subFileName) = subItem, !subFileName.contains("|") {
                            let content = extractFileContent(fileName: subFileName)
                            if !content.isEmpty {
                                results.append((fileName: subFileName, text: String(content.prefix(5000))))
                            }
                        }
                    }
                }
            }
        }
        
        return results
    }
    
    private func extractFileContent(fileName: String) -> String {
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = docsURL.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return "" }
        
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf":
            guard let doc = PDFDocument(url: fileURL) else { return "" }
            var text = ""
            for i in 0..<min(doc.pageCount, 40) {
                if let page = doc.page(at: i), let s = page.string { text += s + "\n" }
            }
            return String(text.prefix(20000))
        case "txt", "md", "csv", "json", "xml", "html":
            return (try? String(contentsOf: fileURL, encoding: .utf8)).map { String($0.prefix(20000)) } ?? ""
        default:
            return ""
        }
    }
}


// MARK: - Spin Modifier

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
