import SwiftUI
import Foundation
import PDFKit
import FoundationModels


// MARK: - Data Models

/// A single topic in the mind map tree. Recursive: each topic can have children.
struct MindMapTopic: Codable, Identifiable {
    var id: UUID
    let title: String
    let summary: String
    let children: [MindMapTopic]
    
    enum CodingKeys: String, CodingKey {
        case title, summary, children
    }
    
    init(id: UUID = UUID(), title: String, summary: String, children: [MindMapTopic] = []) {
        self.id = id
        self.title = title
        self.summary = summary
        self.children = children
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.title = try container.decode(String.self, forKey: .title)
        self.summary = try container.decode(String.self, forKey: .summary)
        self.children = (try? container.decode([MindMapTopic].self, forKey: .children)) ?? []
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(summary, forKey: .summary)
        try container.encode(children, forKey: .children)
    }
}


/// A positioned node ready for rendering. Produced by the layout algorithm.
struct LayoutNode: Identifiable {
    let id: UUID
    let topic: MindMapTopic
    let depth: Int
    let position: CGPoint      // Centre of the node card
    let size: CGSize            // Estimated card size
    let parentID: UUID?         // nil for root
}


/// A connection between two positioned nodes.
struct LayoutEdge: Identifiable {
    let id = UUID()
    let fromID: UUID
    let toID: UUID
    let depth: Int
}


// MARK: - Mind Map Engine

@available(iOS 26.0, *)
struct MindMapEngine {
    
    // MARK: - LLM Generation
    
    /// Generates a mind map topic tree from extracted document text using the on-device LLM.
    static func generateMindMap(
        rootTitle: String,
        documentText: String
    ) async throws -> MindMapTopic {
        
        let prompt = """
        Analyze the following study material and create a structured mind map.
        
        Return ONLY a valid JSON object (no markdown, no code fences) with this exact structure:
        {
          "title": "Main Topic",
          "summary": "One sentence overview of the entire subject",
          "children": [
            {
              "title": "Subtopic 1",
              "summary": "One sentence describing this subtopic",
              "children": [
                {
                  "title": "Detail 1",
                  "summary": "Brief explanation of this specific concept",
                  "children": []
                }
              ]
            }
          ]
        }
        
        Rules:
        - The root title should be "\(rootTitle)"
        - Create 4 to 7 main branches (key topics from the material)
        - Each main branch should have 2 to 4 sub-topics
        - Sub-topics should NOT have further children (max depth = 3)
        - Each "title" must be 2 to 5 words (concise label)
        - Each "summary" must be exactly one sentence (10 to 25 words) explaining the concept
        - Focus on the most important and distinct concepts — avoid repetition
        - Base everything on the provided material only
        
        Study material:
        \(documentText)
        """
        
        let session = LanguageModelSession(
            instructions: "You are a mind map generator. Output ONLY valid JSON. No markdown, no code fences, no explanations — just the raw JSON object."
        )
        
        let response = try await session.respond(to: prompt)
        let content = response.content
        
        return try parseMindMapJSON(from: content, fallbackTitle: rootTitle)
    }
    
    
    // MARK: - JSON Parsing
    
    private static func parseMindMapJSON(from text: String, fallbackTitle: String) throws -> MindMapTopic {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Strip markdown code fences
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Find JSON object bounds
        if let start = cleaned.firstIndex(of: "{"),
           let end = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[start...end])
        }
        
        guard let data = cleaned.data(using: .utf8) else {
            throw MindMapError.invalidJSON
        }
        
        let decoder = JSONDecoder()
        let topic = try decoder.decode(MindMapTopic.self, from: data)
        return topic
    }
    
    
    // MARK: - Tree Layout Algorithm
    
    /// Node sizing constants
    private static let rootNodeWidth: CGFloat = 200
    private static let rootNodeHeight: CGFloat = 70
    private static let branchNodeWidth: CGFloat = 200
    private static let branchNodeHeight: CGFloat = 65
    private static let leafNodeWidth: CGFloat = 190
    private static let leafNodeHeight: CGFloat = 58
    private static let horizontalSpacing: CGFloat = 60
    private static let verticalSpacing: CGFloat = 18
    
    /// Returns the node size based on depth.
    static func nodeSize(forDepth depth: Int) -> CGSize {
        switch depth {
        case 0:  return CGSize(width: rootNodeWidth, height: rootNodeHeight)
        case 1:  return CGSize(width: branchNodeWidth, height: branchNodeHeight)
        default: return CGSize(width: leafNodeWidth, height: leafNodeHeight)
        }
    }
    
    /// Lays out the topic tree into positioned nodes and edges.
    /// Returns (nodes, edges, canvasSize).
    static func layoutTree(_ root: MindMapTopic) -> ([LayoutNode], [LayoutEdge], CGSize) {
        
        // Step 1: Compute subtree heights (bottom-up)
        let subtreeHeights = computeSubtreeHeights(root, depth: 0)
        
        // Step 2: Assign positions (top-down)
        let totalHeight = subtreeHeights
        let startY = totalHeight / 2.0
        let startX: CGFloat = 40 + rootNodeWidth / 2
        
        var nodes: [LayoutNode] = []
        var edges: [LayoutEdge] = []
        
        assignPositions(
            topic: root,
            depth: 0,
            x: startX,
            yMin: startY - totalHeight / 2,
            yMax: startY + totalHeight / 2,
            parentID: nil,
            nodes: &nodes,
            edges: &edges
        )
        
        // Step 3: Compute canvas size
        var maxX: CGFloat = 0
        var maxY: CGFloat = 0
        for node in nodes {
            let right = node.position.x + node.size.width / 2 + 40
            let bottom = node.position.y + node.size.height / 2 + 40
            maxX = max(maxX, right)
            maxY = max(maxY, bottom)
        }
        
        let canvasSize = CGSize(width: maxX + 40, height: max(maxY + 40, 500))
        
        return (nodes, edges, canvasSize)
    }
    
    
    /// Computes the total vertical height needed for a subtree.
    private static func computeSubtreeHeights(_ topic: MindMapTopic, depth: Int) -> CGFloat {
        let size = nodeSize(forDepth: depth)
        
        if topic.children.isEmpty {
            return size.height + verticalSpacing
        }
        
        let childrenHeight = topic.children.reduce(CGFloat(0)) { total, child in
            total + computeSubtreeHeights(child, depth: depth + 1)
        }
        
        return max(size.height + verticalSpacing, childrenHeight)
    }
    
    
    /// Recursively assigns positions to each node.
    private static func assignPositions(
        topic: MindMapTopic,
        depth: Int,
        x: CGFloat,
        yMin: CGFloat,
        yMax: CGFloat,
        parentID: UUID?,
        nodes: inout [LayoutNode],
        edges: inout [LayoutEdge]
    ) {
        let size = nodeSize(forDepth: depth)
        let centerY = (yMin + yMax) / 2
        
        let node = LayoutNode(
            id: topic.id,
            topic: topic,
            depth: depth,
            position: CGPoint(x: x, y: centerY),
            size: size,
            parentID: parentID
        )
        nodes.append(node)
        
        if let parentID = parentID {
            edges.append(LayoutEdge(fromID: parentID, toID: topic.id, depth: depth))
        }
        
        // Lay out children
        guard !topic.children.isEmpty else { return }
        
        let childX = x + size.width / 2 + horizontalSpacing + nodeSize(forDepth: depth + 1).width / 2
        
        // Compute each child's subtree height
        let childHeights = topic.children.map { computeSubtreeHeights($0, depth: depth + 1) }
        let totalChildrenHeight = childHeights.reduce(0, +)
        
        var currentY = centerY - totalChildrenHeight / 2
        
        for (i, child) in topic.children.enumerated() {
            let childHeight = childHeights[i]
            
            assignPositions(
                topic: child,
                depth: depth + 1,
                x: childX,
                yMin: currentY,
                yMax: currentY + childHeight,
                parentID: topic.id,
                nodes: &nodes,
                edges: &edges
            )
            
            currentY += childHeight
        }
    }
    
    
    // MARK: - Text Extraction (budget-aware)
    
    private static let maxTotalContext = 10000
    
    /// Extracts combined text from all files in a stack, respecting a total character budget.
    static func extractText(
        from stack: SubjectStack,
        allStacks: [SubjectStack],
        singleFileName: String? = nil
    ) -> String {
        
        if let fileName = singleFileName {
            return extractSingleFile(fileName: fileName, charLimit: maxTotalContext)
        }
        
        var parts: [String] = []
        var currentLength = 0
        
        for item in stack.files {
            guard currentLength < maxTotalContext else { break }
            
            switch item {
            case .file(_, let fileName):
                if !fileName.contains("|") {
                    let budget = maxTotalContext - currentLength
                    guard budget > 200 else { break }
                    let content = extractSingleFile(fileName: fileName, charLimit: min(4000, budget))
                    if !content.isEmpty {
                        parts.append(content)
                        currentLength += content.count
                    }
                }
            case .folder(let subID):
                if let sub = allStacks.first(where: { $0.id == subID }) {
                    for subItem in sub.files {
                        guard currentLength < maxTotalContext else { break }
                        if case .file(_, let subFileName) = subItem, !subFileName.contains("|") {
                            let budget = maxTotalContext - currentLength
                            guard budget > 200 else { break }
                            let content = extractSingleFile(fileName: subFileName, charLimit: min(2000, budget))
                            if !content.isEmpty {
                                parts.append(content)
                                currentLength += content.count
                            }
                        }
                    }
                }
            }
        }
        
        let joined = parts.joined(separator: "\n\n")
        return String(joined.prefix(maxTotalContext))
    }
    
    
    private static func extractSingleFile(fileName: String, charLimit: Int) -> String {
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = docsURL.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return "" }
        
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf":
            guard let doc = PDFDocument(url: fileURL) else { return "" }
            var text = ""
            for i in 0..<min(doc.pageCount, 15) {
                if let page = doc.page(at: i), let s = page.string {
                    text += s + "\n"
                    if text.count >= charLimit { break }
                }
            }
            return String(text.prefix(charLimit))
        case "txt", "md", "csv", "json", "xml", "html":
            return (try? String(contentsOf: fileURL, encoding: .utf8)).map { String($0.prefix(charLimit)) } ?? ""
        default:
            return ""
        }
    }
}


// MARK: - Errors

enum MindMapError: LocalizedError {
    case invalidJSON
    case emptyContent
    case modelUnavailable
    
    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Could not parse the mind map structure. Please try again."
        case .emptyContent:
            return "Not enough text content to generate a mind map."
        case .modelUnavailable:
            return "Apple Intelligence is not available on this device."
        }
    }
}
