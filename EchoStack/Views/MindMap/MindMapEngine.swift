import SwiftUI
import NaturalLanguage
import Foundation


// MARK: - Data Models

struct MindMapNode: Identifiable {
    let id: UUID
    let title: String
    var position: CGPoint
    let relevance: Double
    let description: String       // Brief context sentence about this topic
    let relatedFiles: [String]    // File names where this keyword appears
}

struct MindMapEdge: Identifiable {
    let id: UUID
    let from: UUID
    let to: UUID
    let weight: Int
}


// MARK: - Mind Map Engine

struct MindMapEngine {
    
    // MARK: - Keyword Extraction with Descriptions & File Sources
    
    /// Extracts keywords along with context descriptions and source file tracking.
    static func extractKeywordsWithContext(
        from fileContents: [(fileName: String, text: String)],
        maxCount: Int = 15
    ) -> [(keyword: String, description: String, files: [String])] {
        
        // Combined text for NLP
        let allText = fileContents.map(\.text).joined(separator: "\n\n")
        
        var frequencyMap: [String: Int] = [:]
        var keywordSentences: [String: String] = [:]   // keyword → best sentence
        var keywordFiles: [String: Set<String>] = [:]   // keyword → set of file names
        
        // 1. Process each file separately to track sources
        for (fileName, text) in fileContents {
            let displayName = cleanFileName(fileName)
            
            // NER
            let nerTagger = NLTagger(tagSchemes: [.nameType])
            nerTagger.string = text
            nerTagger.enumerateTags(
                in: text.startIndex..<text.endIndex,
                unit: .word,
                scheme: .nameType,
                options: [.omitPunctuation, .omitWhitespace, .joinNames]
            ) { tag, range in
                if let tag = tag,
                   [.personalName, .organizationName, .placeName].contains(tag) {
                    let entity = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if entity.count >= 2 {
                        frequencyMap[entity, default: 0] += 3
                        keywordFiles[entity.lowercased(), default: []].insert(displayName)
                    }
                }
                return true
            }
            
            // POS — nouns
            let posTagger = NLTagger(tagSchemes: [.lexicalClass])
            posTagger.string = text
            posTagger.enumerateTags(
                in: text.startIndex..<text.endIndex,
                unit: .word,
                scheme: .lexicalClass,
                options: [.omitPunctuation, .omitWhitespace]
            ) { tag, range in
                if let tag = tag, tag == .noun {
                    let word = String(text[range])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .lowercased()
                    if word.count >= 3 && !Self.stopWords.contains(word) {
                        frequencyMap[word, default: 0] += 1
                        keywordFiles[word, default: []].insert(displayName)
                    }
                }
                return true
            }
        }
        
        // 2. Extract context sentences from combined text
        let sentenceTokenizer = NLTokenizer(unit: .sentence)
        sentenceTokenizer.string = allText
        var sentences: [String] = []
        sentenceTokenizer.enumerateTokens(in: allText.startIndex..<allText.endIndex) { range, _ in
            let sentence = String(allText[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if sentence.count > 15 && sentence.count < 300 {
                sentences.append(sentence)
            }
            return true
        }
        
        // 3. Sort by frequency, deduplicate, take top N
        let sorted = frequencyMap.sorted { $0.value > $1.value }
        
        var seen = Set<String>()
        var results: [(keyword: String, description: String, files: [String])] = []
        
        for (word, _) in sorted {
            let normalized = word.lowercased()
            if !seen.contains(normalized) {
                seen.insert(normalized)
                
                let displayWord = word.prefix(1).uppercased() + word.dropFirst()
                
                // Find best context sentence
                let contextSentence = sentences.first(where: {
                    $0.lowercased().contains(normalized)
                }) ?? "A key topic found in your materials."
                
                // Trim to a reasonable length
                let trimmedContext = String(contextSentence.prefix(150))
                
                let files = Array(keywordFiles[normalized] ?? []).sorted()
                
                results.append((keyword: displayWord, description: trimmedContext, files: files))
            }
            if results.count >= maxCount { break }
        }
        
        return results
    }
    
    /// Simple keyword extraction (legacy, for single-file use)
    static func extractKeywords(from text: String, maxCount: Int = 15) -> [String] {
        let results = extractKeywordsWithContext(
            from: [("file", text)],
            maxCount: maxCount
        )
        return results.map(\.keyword)
    }
    
    // MARK: - Edge Generation
    
    static func generateEdges(
        keywords: [String],
        text: String,
        nodes: [MindMapNode]
    ) -> [MindMapEdge] {
        
        let titleToID: [String: UUID] = Dictionary(
            uniqueKeysWithValues: nodes.map { ($0.title.lowercased(), $0.id) }
        )
        
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            sentences.append(String(text[range]).lowercased())
            return true
        }
        
        var coOccurrence: [String: Int] = [:]
        let lowercasedKeywords = keywords.map { $0.lowercased() }
        
        for sentence in sentences {
            var present: [Int] = []
            for (i, kw) in lowercasedKeywords.enumerated() {
                if sentence.contains(kw) {
                    present.append(i)
                }
            }
            for i in 0..<present.count {
                for j in (i+1)..<present.count {
                    let key = "\(min(present[i], present[j]))-\(max(present[i], present[j]))"
                    coOccurrence[key, default: 0] += 1
                }
            }
        }
        
        var edges: [MindMapEdge] = []
        
        for (key, count) in coOccurrence {
            let parts = key.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 2 else { continue }
            let kwA = lowercasedKeywords[parts[0]]
            let kwB = lowercasedKeywords[parts[1]]
            if let idA = titleToID[kwA], let idB = titleToID[kwB] {
                edges.append(MindMapEdge(id: UUID(), from: idA, to: idB, weight: count))
            }
        }
        
        if edges.count < nodes.count / 2 {
            let connectedNodes = Set(edges.flatMap { [$0.from, $0.to] })
            for node in nodes where !connectedNodes.contains(node.id) {
                if let center = nodes.first, center.id != node.id {
                    edges.append(MindMapEdge(id: UUID(), from: center.id, to: node.id, weight: 1))
                }
            }
        }
        
        return edges
    }
    
    // MARK: - Radial Jitter Layout
    
    static func generateNodePositions(
        from keywordsWithContext: [(keyword: String, description: String, files: [String])],
        canvasSize: CGSize
    ) -> [MindMapNode] {
        guard !keywordsWithContext.isEmpty else { return [] }
        
        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        var nodes: [MindMapNode] = []
        let total = keywordsWithContext.count
        
        // First keyword = center node
        let first = keywordsWithContext[0]
        nodes.append(MindMapNode(
            id: UUID(),
            title: first.keyword,
            position: center,
            relevance: 1.0,
            description: first.description,
            relatedFiles: first.files
        ))
        
        if total == 1 { return nodes }
        
        let innerRing = min(total - 1, 8)
        let outerRing = max(0, total - 1 - innerRing)
        
        for i in 0..<innerRing {
            let angle = (Double(i) / Double(innerRing)) * 2 * .pi
            let baseRadius = min(Double(canvasSize.width), Double(canvasSize.height)) * 0.25
            let jitter = Double.random(in: -20...20)
            let radius = baseRadius + jitter
            let angleJitter = Double.random(in: -0.15...0.15)
            
            let x = center.x + CGFloat(cos(angle + angleJitter) * radius)
            let y = center.y + CGFloat(sin(angle + angleJitter) * radius)
            let relevance = max(0.4, 1.0 - (Double(i + 1) / Double(total)))
            
            let item = keywordsWithContext[i + 1]
            nodes.append(MindMapNode(
                id: UUID(),
                title: item.keyword,
                position: CGPoint(x: x, y: y),
                relevance: relevance,
                description: item.description,
                relatedFiles: item.files
            ))
        }
        
        for i in 0..<outerRing {
            let angle = (Double(i) / Double(outerRing)) * 2 * .pi
            let offset = Double.random(in: -0.2...0.2)
            let baseRadius = min(Double(canvasSize.width), Double(canvasSize.height)) * 0.4
            let jitter = Double.random(in: -15...15)
            let radius = baseRadius + jitter
            
            let x = center.x + CGFloat(cos(angle + offset) * radius)
            let y = center.y + CGFloat(sin(angle + offset) * radius)
            
            let item = keywordsWithContext[innerRing + 1 + i]
            nodes.append(MindMapNode(
                id: UUID(),
                title: item.keyword,
                position: CGPoint(x: x, y: y),
                relevance: 0.3,
                description: item.description,
                relatedFiles: item.files
            ))
        }
        
        return nodes
    }
    
    // MARK: - Helpers
    
    private static func cleanFileName(_ name: String) -> String {
        if name.contains("|") {
            return name.components(separatedBy: "|").first ?? name
        }
        return (name as NSString).deletingPathExtension
    }
    
    // MARK: - Stop Words
    
    static let stopWords: Set<String> = [
        "the", "and", "for", "are", "but", "not", "you", "all", "any", "can",
        "her", "was", "one", "our", "out", "has", "have", "had", "been", "this",
        "that", "with", "from", "they", "will", "would", "there", "their", "what",
        "about", "which", "when", "make", "like", "time", "just", "know", "take",
        "people", "into", "year", "your", "good", "some", "could", "them", "than",
        "other", "how", "its", "also", "after", "use", "two", "way", "first",
        "then", "new", "because", "these", "most", "day", "more", "each", "much",
        "should", "may", "very", "such", "here", "between", "being", "under",
        "does", "did", "get", "same", "back", "only", "come", "made", "well",
        "where", "still", "every", "name", "keep", "thing", "need", "many", "etc",
        "example", "using", "used", "based", "given", "following", "different",
        "number", "point", "part", "case", "however", "information", "system"
    ]
}
