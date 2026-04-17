import SwiftUI


// MARK: - Stack Chat View
@available(iOS 26.0, *)
struct StackChatView: View {
    
    @State private var viewModel: ChatViewModel
    @FocusState private var isInputFocused: Bool
    @Environment(\.dismiss) private var dismiss
    
    let stackColor: Color
    let stackTitle: String
    
    let paperBackground = Color(red: 0.98, green: 0.97, blue: 0.95)
    let inkColor = Color(red: 0.1, green: 0.1, blue: 0.15)
    
    init(stack: SubjectStack, allStacks: [SubjectStack]) {
        self.stackColor = stack.color.swiftUIColor
        self.stackTitle = stack.title
        _viewModel = State(initialValue: ChatViewModel(stack: stack, allStacks: allStacks))
    }
    
    var body: some View {
        ZStack {
            paperBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                chatHeader
                
                Divider()
                    .background(stackColor.opacity(0.3))
                
                // Content
                if viewModel.isLoadingContext {
                    loadingView
                } else if !viewModel.isModelAvailable {
                    unavailableView
                } else {
                    // Messages
                    messagesScrollView
                    
                    Divider()
                        .background(stackColor.opacity(0.2))
                    
                    // Input Bar
                    inputBar
                }
            }
        }
        .onTapGesture {
            isInputFocused = false
        }
        .navigationBarHidden(true)
        .task {
            await viewModel.loadStackContext()
        }
    }
}


// MARK: - Header
@available(iOS 26.0, *)
extension StackChatView {
    
    private var chatHeader: some View {
        HStack(spacing: 12) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(stackColor)
            }
            
            // Stack icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(stackColor)
                    .frame(width: 36, height: 36)
                
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Study Assistant")
                    .font(.system(.headline, design: .serif))
                    .foregroundColor(inkColor)
                
                Text(stackTitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(
            paperBackground
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        )
    }
}


// MARK: - Messages
@available(iOS 26.0, *)
extension StackChatView {
    
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(
                            message: message,
                            stackColor: stackColor,
                            inkColor: inkColor
                        )
                        .id(message.id)
                    }
                    
                    // Typing indicator
                    if viewModel.isGenerating {
                        TypingIndicatorView(color: stackColor)
                            .id("typing")
                    }
                }
                .padding()
                .padding(.bottom, 8)
            }
            .onChange(of: viewModel.messages.count) {
                withAnimation(.easeOut(duration: 0.3)) {
                    if let lastMessage = viewModel.messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.messages.last?.content) {
                withAnimation(.easeOut(duration: 0.15)) {
                    if viewModel.isGenerating, let lastMessage = viewModel.messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}


// MARK: - Input Bar
@available(iOS 26.0, *)
extension StackChatView {
    
    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            // Text Field
            HStack(spacing: 8) {
                Image(systemName: "text.quote")
                    .font(.system(size: 14))
                    .foregroundColor(stackColor.opacity(0.5))
                
                TextField("Ask about your notes...", text: $viewModel.inputText, axis: .vertical)
                    .font(.system(.body, design: .serif))
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .onSubmit {
                        Task { await viewModel.sendMessage() }
                    }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                isInputFocused ? stackColor.opacity(0.4) : Color.black.opacity(0.08),
                                lineWidth: 1.5
                            )
                    )
            )
            
            // Send Button
            Button {
                Task { await viewModel.sendMessage() }
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isGenerating
                            ? Color.gray.opacity(0.3)
                            : stackColor
                        )
                        .frame(width: 38, height: 38)
                    
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isGenerating)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            paperBackground
                .shadow(color: .black.opacity(0.06), radius: 8, y: -2)
        )
    }
}


// MARK: - State Views
@available(iOS 26.0, *)
extension StackChatView {
    
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
                    .modifier(SpinModifier())
                
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 22))
                    .foregroundColor(stackColor)
            }
            
            VStack(spacing: 8) {
                Text("Analyzing Your Materials")
                    .font(.system(.headline, design: .serif))
                    .foregroundColor(inkColor)
                
                Text("Reading documents and building context...")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    private var unavailableView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "apple.intelligence")
                .font(.system(size: 50))
                .foregroundColor(.secondary.opacity(0.4))
            
            VStack(spacing: 8) {
                Text("Apple Intelligence Required")
                    .font(.system(.headline, design: .serif))
                    .foregroundColor(inkColor)
                
                Text(viewModel.errorMessage ?? "Please enable Apple Intelligence in Settings to use the Study Assistant.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
        }
    }
}


// MARK: - Message Bubble
struct MessageBubbleView: View {
    let message: ChatMessage
    let stackColor: Color
    let inkColor: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if message.role == .user {
                Spacer(minLength: 50)
            }
            
            if message.role == .assistant {
                // Assistant avatar
                ZStack {
                    Circle()
                        .fill(stackColor.opacity(0.15))
                        .frame(width: 30, height: 30)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(stackColor)
                }
                .padding(.top, 4)
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(markdownAttributedString(from: message.content))
                    .font(.system(size: 15, design: .serif))
                    .foregroundColor(message.role == .user ? .white : inkColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Group {
                            if message.role == .user {
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(stackColor)
                            } else {
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color.white)
                                    .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
                            }
                        }
                    )
                
                Text(message.timestamp, style: .time)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.horizontal, 6)
            }
            
            if message.role == .assistant {
                Spacer(minLength: 50)
            }
        }
    }
    
    /// Converts markdown text to an AttributedString for proper rendering
    private func markdownAttributedString(from text: String) -> AttributedString {
        if let attributed = try? AttributedString(markdown: text) {
            return attributed
        }
        return AttributedString(text)
    }
}


// MARK: - Typing Indicator
struct TypingIndicatorView: View {
    let color: Color
    @State private var animationPhase: CGFloat = 0
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 30, height: 30)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(color)
            }
            
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(color.opacity(0.5))
                        .frame(width: 7, height: 7)
                        .offset(y: animationPhase == CGFloat(index) ? -5 : 0)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                    animationPhase = 2
                }
            }
            
            Spacer()
        }
    }
}


// MARK: - Spin Animation Modifier
struct SpinModifier: ViewModifier {
    @State private var rotation: Double = 0
    
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}
