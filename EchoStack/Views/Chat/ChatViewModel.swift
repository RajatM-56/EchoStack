import SwiftUI
import Foundation
import PDFKit
import FoundationModels

// MARK: - Chat Message Model
struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let role: MessageRole
    var content: String
    let timestamp: Date
    
    enum MessageRole {
        case user
        case assistant
        case system
    }
    
    init(id: UUID = UUID(), role: MessageRole, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}


// MARK: - Chat ViewModel
@available(iOS 26.0, *)
@Observable
@MainActor
final class ChatViewModel {
    
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isGenerating: Bool = false
    var errorMessage: String?
    var isModelAvailable: Bool = false
    var extractedContext: String = ""
    var isLoadingContext: Bool = false
    
    private var session: LanguageModelSession?
    private let stack: SubjectStack
    private let allStacks: [SubjectStack]
    
    /// Maximum total characters to feed into the LLM session instructions.
    private let maxTotalContext = 16000
    
    init(stack: SubjectStack, allStacks: [SubjectStack]) {
        self.stack = stack
        self.allStacks = allStacks
        checkModelAvailability()
    }
    
    // MARK: - Model Availability
    
    func checkModelAvailability() {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            isModelAvailable = true
        default:
            isModelAvailable = false
            errorMessage = "Apple Intelligence is not available on this device. Please ensure Apple Intelligence is enabled in Settings."
        }
    }
    
    // MARK: - Context Extraction
    
    func loadStackContext() async {
        isLoadingContext = true
        defer { isLoadingContext = false }
        
        var contextParts: [String] = []
        contextParts.append("Subject: \(stack.title)")
        contextParts.append("Number of items: \(stack.files.count)")
        var currentLength = contextParts.joined(separator: "\n").count
        
        // Extract text from all files in the stack
        for item in stack.files {
            guard currentLength < maxTotalContext else { break }
            
            switch item {
            case .file(_, let fileName):
                if fileName.contains("|") {
                    // It's a link
                    let components = fileName.components(separatedBy: "|")
                    let displayName = components.first ?? fileName
                    let url = components.last ?? ""
                    let chunk = "\n--- Web Link: \(displayName) ---\nURL: \(url)"
                    contextParts.append(chunk)
                    currentLength += chunk.count
                } else {
                    // It's a file — try to extract content
                    let budget = maxTotalContext - currentLength
                    guard budget > 200 else { break }
                    let fileContent = extractFileContent(fileName: fileName, charLimit: min(5000, budget))
                    if !fileContent.isEmpty {
                        let chunk = "\n--- Document: \(fileName) ---\n\(fileContent)"
                        contextParts.append(chunk)
                        currentLength += chunk.count
                    } else {
                        contextParts.append("\n--- File: \(fileName) (content could not be extracted) ---")
                    }
                }
                
            case .folder(let subFolderID):
                if let subStack = allStacks.first(where: { $0.id == subFolderID }) {
                    let budget = maxTotalContext - currentLength
                    guard budget > 200 else { break }
                    let subContext = extractSubFolderContext(stack: subStack, depth: 1, charLimit: min(3000, budget))
                    contextParts.append(subContext)
                    currentLength += subContext.count
                }
            }
        }
        
        let joined = contextParts.joined(separator: "\n")
        extractedContext = String(joined.prefix(maxTotalContext))
        
        // Initialize the session with the grounded context
        initializeSession()
        
        // Add welcome message
        let fileCount = stack.files.count
        let welcomeContent = "Hello! I'm your study assistant for **\(stack.title)**. I've analyzed \(fileCount) item\(fileCount == 1 ? "" : "s") in this stack. Ask me anything about your materials!"
        messages.append(ChatMessage(role: .assistant, content: welcomeContent))
    }
    
    private func extractSubFolderContext(stack: SubjectStack, depth: Int, charLimit: Int = 3000) -> String {
        guard depth <= 3 else { return "" }
        
        var parts: [String] = []
        let indent = String(repeating: "  ", count: depth)
        parts.append("\(indent)Sub-Folder: \(stack.title)")
        var currentLength = parts.first!.count
        
        for item in stack.files {
            guard currentLength < charLimit else { break }
            
            switch item {
            case .file(_, let fileName):
                if fileName.contains("|") {
                    let components = fileName.components(separatedBy: "|")
                    let displayName = components.first ?? fileName
                    parts.append("\(indent)  Link: \(displayName)")
                    currentLength += displayName.count + 10
                } else {
                    let budget = charLimit - currentLength
                    guard budget > 100 else { break }
                    let content = extractFileContent(fileName: fileName, charLimit: min(1000, budget))
                    if !content.isEmpty {
                        let chunk = "\(indent)  Document: \(fileName)\n\(content)"
                        parts.append(chunk)
                        currentLength += chunk.count
                    }
                }
            case .folder(let subID):
                if let sub = allStacks.first(where: { $0.id == subID }) {
                    let budget = charLimit - currentLength
                    guard budget > 100 else { break }
                    parts.append(extractSubFolderContext(stack: sub, depth: depth + 1, charLimit: min(1000, budget)))
                }
            }
        }
        
        return parts.joined(separator: "\n")
    }
    
    // MARK: - File Content Extraction
    
    private func extractFileContent(fileName: String, charLimit: Int = 5000) -> String {
        let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = docsURL.appendingPathComponent(fileName)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return "" }
        
        let ext = (fileName as NSString).pathExtension.lowercased()
        
        switch ext {
        case "pdf":
            return extractPDFText(from: fileURL, charLimit: charLimit)
        case "txt", "md", "rtf", "csv", "json", "xml", "html", "swift", "py", "js":
            return extractPlainText(from: fileURL, charLimit: charLimit)
        case "doc", "docx":
            // Attempt attributed string extraction for doc/docx
            return extractAttributedText(from: fileURL, charLimit: charLimit)
        default:
            return ""
        }
    }
    
    private func extractPDFText(from url: URL, charLimit: Int = 5000) -> String {
        guard let pdfDocument = PDFDocument(url: url) else { return "" }
        
        var fullText = ""
        let pageLimit = min(pdfDocument.pageCount, 20) // Limit pages for context
        
        for i in 0..<pageLimit {
            if let page = pdfDocument.page(at: i),
               let pageText = page.string {
                fullText += pageText + "\n"
                if fullText.count >= charLimit { break }
            }
        }
        
        // Truncate to the budget
        return String(fullText.prefix(charLimit))
    }
    
    private func extractPlainText(from url: URL, charLimit: Int = 5000) -> String {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return String(text.prefix(charLimit))
    }
    
    private func extractAttributedText(from url: URL, charLimit: Int = 5000) -> String {
        guard let data = try? Data(contentsOf: url),
              let attributed = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtfd],
                documentAttributes: nil
              ) else { return "" }
        return String(attributed.string.prefix(charLimit))
    }
    
    // MARK: - Session Management
    
    private func initializeSession() {
        guard isModelAvailable else { return }
        
        let instructions = """
        You are an intelligent study assistant for a subject called "\(stack.title)".
        You have been provided with the contents of the user's documents and files from this subject stack.
        
        Your role is to:
        - Answer questions about the content in the user's documents accurately and helpfully.
        - Summarize key concepts, definitions, or sections when asked.
        - Help the user study by creating practice questions, flashcards, or quizzes from their material.
        - Explain difficult concepts in simpler terms.
        - Cross-reference information across different documents in the stack.
        
        When answering, always prioritize information from the documents provided below. If the user asks something that is clearly not covered anywhere in the provided materials, let them know politely — for example: "I couldn't find that in your current documents. You could try adding more materials to this stack!"
        
        Be concise yet thorough. Use markdown formatting in your responses when helpful (bold for key terms, bullet points for lists, etc.).
        
        Formatting guidelines:
        - Use **bold** for key terms, definitions, and important concepts.
        - Use bullet points or numbered lists for steps, multiple items, or comparisons.
        - Use short paragraphs — avoid walls of text.
        - When explaining a concept, start with a brief one-line summary, then elaborate.
        - Use headings (## or ###) only for long, multi-section answers.
        - Keep responses clean and readable. Do not use excessive punctuation or symbols.
        
        Here is all the content from the user's stack:
        
        \(extractedContext)
        """
        
        session = LanguageModelSession(instructions: instructions)
    }
    
    // MARK: - Send Message
    
    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isGenerating else { return }
        
        inputText = ""
        isGenerating = true
        errorMessage = nil
        
        // Add user message
        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        
        // Add placeholder for assistant response
        let assistantMessage = ChatMessage(role: .assistant, content: "")
        messages.append(assistantMessage)
        let assistantIndex = messages.count - 1
        
        do {
            guard let session = session else {
                throw ChatError.sessionNotInitialized
            }
            
            // Use streaming for a responsive UI
            let stream = session.streamResponse(to: text)
            
            for try await partial in stream {
                messages[assistantIndex].content = partial.content
            }
            
        } catch {
            messages[assistantIndex].content = "Sorry, I encountered an error: \(error.localizedDescription)"
            errorMessage = error.localizedDescription
        }
        
        isGenerating = false
    }
}


// MARK: - Errors

enum ChatError: LocalizedError {
    case sessionNotInitialized
    case modelUnavailable
    
    var errorDescription: String? {
        switch self {
        case .sessionNotInitialized:
            return "The AI session could not be started. Please try again."
        case .modelUnavailable:
            return "Apple Intelligence is not available on this device."
        }
    }
}
