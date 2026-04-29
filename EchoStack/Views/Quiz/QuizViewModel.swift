import SwiftUI
import Foundation
import PDFKit
import FoundationModels


// MARK: - Quiz Question Model

struct MCQuestion: Identifiable, Codable {
    var id: UUID = UUID()
    let question: String
    let options: [String]
    let correctIndex: Int
    let explanation: String
    
    enum CodingKeys: String, CodingKey {
        case question, options, correctIndex, explanation
    }
}


// MARK: - Quiz State

enum QuizPhase {
    case setup
    case generating
    case active
    case results
}


// MARK: - Quiz ViewModel

@available(iOS 26.0, *)
@Observable
@MainActor
final class QuizViewModel {
    
    var phase: QuizPhase = .setup
    var questions: [MCQuestion] = []
    var currentIndex: Int = 0
    var selectedAnswer: Int? = nil
    var hasAnswered: Bool = false
    var score: Int = 0
    var questionCount: Int = 10
    var errorMessage: String?
    var isModelAvailable: Bool = false
    
    private let stack: SubjectStack
    private let allStacks: [SubjectStack]
    private var extractedContext: String = ""
    
    init(stack: SubjectStack, allStacks: [SubjectStack]) {
        self.stack = stack
        self.allStacks = allStacks
        checkModelAvailability()
    }
    
    var currentQuestion: MCQuestion? {
        guard currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }
    
    var progress: Double {
        guard !questions.isEmpty else { return 0 }
        return Double(currentIndex) / Double(questions.count)
    }
    
    var scorePercentage: Int {
        guard !questions.isEmpty else { return 0 }
        return Int((Double(score) / Double(questions.count)) * 100)
    }
    
    // MARK: - Availability
    
    func checkModelAvailability() {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            isModelAvailable = true
        default:
            isModelAvailable = false
            errorMessage = "Apple Intelligence is not available on this device."
        }
    }
    
    // MARK: - Generate Quiz
    
    func generateQuiz() async {
        phase = .generating
        errorMessage = nil
        
        // 1. Extract context from the stack
        extractedContext = buildContext()
        
        // 2. Build the prompt
        let prompt = """
        Based on the following study material, generate exactly \(questionCount) multiple choice questions for exam practice.
        
        Return ONLY a valid JSON array with no extra text. Each object must have:
        - "question": the question text
        - "options": an array of exactly 4 option strings
        - "correctIndex": the index (0-3) of the correct option
        - "explanation": a brief one-line explanation of why the answer is correct
        
        Example format:
        [{"question":"What is...?","options":["A","B","C","D"],"correctIndex":0,"explanation":"Because..."}]
        
        Study material:
        \(extractedContext)
        """
        
        do {
            guard isModelAvailable else { throw ChatError.modelUnavailable }
            
            let session = LanguageModelSession(instructions: "You are a quiz generator. You output ONLY valid JSON arrays of MCQ objects. No markdown, no code fences, no extra text — just the raw JSON array.")
            
            let response = try await session.respond(to: prompt)
            let content = response.content
            
            // Parse JSON
            let parsed = try parseQuestions(from: content)
            
            if parsed.isEmpty {
                errorMessage = "Could not generate questions. Try again."
                phase = .setup
                return
            }
            
            questions = parsed
            currentIndex = 0
            score = 0
            selectedAnswer = nil
            hasAnswered = false
            phase = .active
            
        } catch {
            errorMessage = "Generation failed: \(error.localizedDescription)"
            phase = .setup
        }
    }
    
    // MARK: - Parse JSON Response
    
    private func parseQuestions(from text: String) throws -> [MCQuestion] {
        // Clean up: strip markdown code fences if present
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Find JSON array bounds
        if let start = cleaned.firstIndex(of: "["),
           let end = cleaned.lastIndex(of: "]") {
            cleaned = String(cleaned[start...end])
        }
        
        guard let data = cleaned.data(using: .utf8) else {
            return []
        }
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode([MCQuestion].self, from: data)
        return decoded
    }
    
    // MARK: - Quiz Actions
    
    func selectAnswer(_ index: Int) {
        guard !hasAnswered else { return }
        selectedAnswer = index
        hasAnswered = true
        
        if let question = currentQuestion, index == question.correctIndex {
            score += 1
        }
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    func nextQuestion() {
        if currentIndex + 1 >= questions.count {
            withAnimation(.spring(response: 0.5)) {
                phase = .results
            }
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                currentIndex += 1
                selectedAnswer = nil
                hasAnswered = false
            }
        }
    }
    
    func restartQuiz() {
        withAnimation(.spring(response: 0.4)) {
            currentIndex = 0
            score = 0
            selectedAnswer = nil
            hasAnswered = false
            phase = .active
        }
    }
    
    func backToSetup() {
        withAnimation(.spring(response: 0.4)) {
            questions = []
            currentIndex = 0
            score = 0
            selectedAnswer = nil
            hasAnswered = false
            phase = .setup
        }
    }
    
    // MARK: - Context Building
    
    /// Maximum total characters to feed into the LLM prompt.
    private let maxTotalContext = 12000
    
    private func buildContext() -> String {
        var parts: [String] = []
        parts.append("Subject: \(stack.title)")
        var currentLength = parts.first!.count
        
        for item in stack.files {
            guard currentLength < maxTotalContext else { break }
            
            switch item {
            case .file(_, let fileName):
                if fileName.contains("|") {
                    let name = fileName.components(separatedBy: "|").first ?? fileName
                    parts.append("Link: \(name)")
                    currentLength += name.count + 10
                } else {
                    let budget = maxTotalContext - currentLength
                    guard budget > 200 else { break }
                    let content = extractFileContent(fileName: fileName, charLimit: min(4000, budget))
                    if !content.isEmpty {
                        let chunk = "--- \(fileName) ---\n\(content)"
                        parts.append(chunk)
                        currentLength += chunk.count
                    }
                }
            case .folder(let subID):
                if let sub = allStacks.first(where: { $0.id == subID }) {
                    let budget = maxTotalContext - currentLength
                    guard budget > 200 else { break }
                    let subContext = buildSubContext(stack: sub, depth: 1, charLimit: min(2000, budget))
                    parts.append(subContext)
                    currentLength += subContext.count
                }
            }
        }
        
        let joined = parts.joined(separator: "\n")
        return String(joined.prefix(maxTotalContext))
    }
    
    private func buildSubContext(stack: SubjectStack, depth: Int, charLimit: Int = 2000) -> String {
        guard depth <= 3 else { return "" }
        var parts: [String] = ["Sub-Folder: \(stack.title)"]
        var currentLength = parts.first!.count
        
        for item in stack.files {
            guard currentLength < charLimit else { break }
            if case .file(_, let fileName) = item, !fileName.contains("|") {
                let budget = charLimit - currentLength
                guard budget > 100 else { break }
                let content = extractFileContent(fileName: fileName, charLimit: min(1000, budget))
                if !content.isEmpty {
                    parts.append(content)
                    currentLength += content.count
                }
            }
        }
        return parts.joined(separator: "\n")
    }
    
    private func extractFileContent(fileName: String, charLimit: Int = 4000) -> String {
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = docsURL.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return "" }
        
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf":
            return extractPDFText(from: fileURL, charLimit: charLimit)
        case "txt", "md", "rtf", "csv", "json", "xml", "html":
            return (try? String(contentsOf: fileURL, encoding: .utf8)).map { String($0.prefix(charLimit)) } ?? ""
        default:
            return ""
        }
    }
    
    private func extractPDFText(from url: URL, charLimit: Int = 4000) -> String {
        guard let doc = PDFDocument(url: url) else { return "" }
        var text = ""
        for i in 0..<min(doc.pageCount, 15) {
            if let page = doc.page(at: i), let s = page.string {
                text += s + "\n"
                if text.count >= charLimit { break }
            }
        }
        return String(text.prefix(charLimit))
    }
}
