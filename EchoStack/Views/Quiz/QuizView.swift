import SwiftUI


// MARK: - Quiz View
@available(iOS 26.0, *)
struct QuizView: View {
    
    @State private var viewModel: QuizViewModel
    @Environment(\.dismiss) private var dismiss
    
    let stackColor: Color
    let stackTitle: String
    
    let paperBackground = Color(red: 0.98, green: 0.97, blue: 0.95)
    let inkColor = Color(red: 0.1, green: 0.1, blue: 0.15)
    
    init(stack: SubjectStack, allStacks: [SubjectStack]) {
        self.stackColor = stack.color.swiftUIColor
        self.stackTitle = stack.title
        _viewModel = State(initialValue: QuizViewModel(stack: stack, allStacks: allStacks))
    }
    
    var body: some View {
        ZStack {
            paperBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                quizHeader
                
                Divider().background(stackColor.opacity(0.3))
                
                switch viewModel.phase {
                case .setup:
                    setupView
                case .generating:
                    generatingView
                case .active:
                    activeQuizView
                case .results:
                    resultsView
                }
            }
        }
        .navigationBarHidden(true)
    }
}


// MARK: - Header
@available(iOS 26.0, *)
extension QuizView {
    
    private var quizHeader: some View {
        HStack(spacing: 12) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(stackColor)
            }
            
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(stackColor)
                    .frame(width: 36, height: 36)
                
                Image(systemName: "questionmark.text.page.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Practice Quiz")
                    .font(.system(.headline, design: .serif))
                    .foregroundColor(inkColor)
                
                Text(stackTitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Progress (shown during active quiz)
            if viewModel.phase == .active {
                Text("\(viewModel.currentIndex + 1)/\(viewModel.questions.count)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(stackColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(stackColor.opacity(0.1))
                    )
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(
            paperBackground
                .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        )
    }
}


// MARK: - Setup View
@available(iOS 26.0, *)
extension QuizView {
    
    private var setupView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(stackColor.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 40))
                    .foregroundColor(stackColor)
            }
            
            VStack(spacing: 8) {
                Text("Test Your Knowledge")
                    .font(.system(.title2, design: .serif).bold())
                    .foregroundColor(inkColor)
                
                Text("Generate practice MCQs from your **\(stackTitle)** materials")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // Question count picker
            VStack(spacing: 12) {
                Text("NUMBER OF QUESTIONS")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.secondary)
                    .kerning(1.5)
                
                HStack(spacing: 12) {
                    ForEach([5, 10, 15, 20], id: \.self) { count in
                        QuestionCountChip(
                            count: count,
                            isSelected: viewModel.questionCount == count,
                            color: stackColor
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                viewModel.questionCount = count
                            }
                            UISelectionFeedbackGenerator().selectionChanged()
                        }
                    }
                }
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.04), radius: 10)
            )
            .padding(.horizontal, 30)
            
            // Error message
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            
            // Generate button
            Button {
                Task { await viewModel.generateQuiz() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Generate Quiz")
                        .font(.system(.headline, design: .serif))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(stackColor)
                        .shadow(color: stackColor.opacity(0.3), radius: 10, y: 5)
                )
            }
            .padding(.horizontal, 30)
            .disabled(!viewModel.isModelAvailable)
            
            Spacer()
            Spacer()
        }
    }
}


// MARK: - Generating View
@available(iOS 26.0, *)
extension QuizView {
    
    private var generatingView: some View {
        VStack(spacing: 25) {
            Spacer()
            
            ZStack {
                // Orbiting dots
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(stackColor.opacity(0.6))
                        .frame(width: 10, height: 10)
                        .offset(y: -35)
                        .rotationEffect(.degrees(Double(i) * 120))
                        .modifier(OrbitModifier(speed: 1.5 + Double(i) * 0.3))
                }
                
                ZStack {
                    Circle()
                        .fill(stackColor.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 30))
                        .foregroundColor(stackColor)
                        .symbolEffect(.pulse)
                }
            }
            .frame(width: 100, height: 100)
            
            VStack(spacing: 8) {
                Text("Crafting Your Quiz")
                    .font(.system(.title3, design: .serif).bold())
                    .foregroundColor(inkColor)
                
                Text("Generating \(viewModel.questionCount) questions from your materials...")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}


// MARK: - Active Quiz (Flashcard)
@available(iOS 26.0, *)
extension QuizView {
    
    private var activeQuizView: some View {
        VStack(spacing: 20) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(stackColor.opacity(0.12))
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(stackColor)
                        .frame(width: geo.size.width * viewModel.progress, height: 6)
                        .animation(.spring(response: 0.4), value: viewModel.progress)
                }
            }
            .frame(height: 6)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            if let question = viewModel.currentQuestion {
                ScrollView {
                    VStack(spacing: 20) {
                        // Question card
                        questionCard(question)
                        
                        // Options (cap at 4)
                        ForEach(Array(question.options.prefix(4).enumerated()), id: \.offset) { index, option in
                            optionButton(index: index, text: option, question: question)
                        }
                        
                        // Explanation (after answering)
                        if viewModel.hasAnswered {
                            explanationCard(question)
                            
                            // Next button
                            Button {
                                viewModel.nextQuestion()
                            } label: {
                                HStack(spacing: 8) {
                                    Text(viewModel.currentIndex + 1 >= viewModel.questions.count ? "See Results" : "Next Question")
                                        .font(.system(.headline, design: .serif))
                                    Image(systemName: viewModel.currentIndex + 1 >= viewModel.questions.count ? "trophy.fill" : "arrow.right")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(stackColor)
                                )
                            }
                            .padding(.horizontal, 4)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
        }
    }
    
    private func questionCard(_ question: MCQuestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("QUESTION \(viewModel.currentIndex + 1)")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(stackColor)
                    .kerning(1.5)
                
                Spacer()
                
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14))
                    .foregroundColor(stackColor.opacity(0.4))
            }
            
            Text(question.question)
                .font(.system(size: 18, weight: .medium, design: .serif))
                .foregroundColor(inkColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        )
    }
    
    private func optionButton(index: Int, text: String, question: MCQuestion) -> some View {
        let isSelected = viewModel.selectedAnswer == index
        let isCorrect = index == question.correctIndex
        let showResult = viewModel.hasAnswered
        
        let bgColor: Color = {
            if !showResult { return isSelected ? stackColor.opacity(0.08) : Color.white }
            if isCorrect { return Color.green.opacity(0.12) }
            if isSelected && !isCorrect { return Color.red.opacity(0.12) }
            return Color.white.opacity(0.6)
        }()
        
        let borderColor: Color = {
            if !showResult { return isSelected ? stackColor : Color.black.opacity(0.06) }
            if isCorrect { return Color.green }
            if isSelected && !isCorrect { return Color.red }
            return Color.clear
        }()
        
        let iconName: String = {
            if !showResult { return optionLetter(index) }
            if isCorrect { return "checkmark.circle.fill" }
            if isSelected && !isCorrect { return "xmark.circle.fill" }
            return optionLetter(index)
        }()
        
        let iconColor: Color = {
            if !showResult { return stackColor }
            if isCorrect { return .green }
            if isSelected && !isCorrect { return .red }
            return .secondary
        }()
        
        return Button {
            viewModel.selectAnswer(index)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    if showResult && (isCorrect || (isSelected && !isCorrect)) {
                        Image(systemName: iconName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(iconColor)
                    } else {
                        let letters = ["A", "B", "C", "D"]
                        Circle().fill(iconColor.opacity(0.1))
                        Text(index < letters.count ? letters[index] : "\(index + 1)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(iconColor)
                    }
                }
                .frame(width: 30, height: 30)
                
                Text(text)
                    .font(.system(size: 15, design: .serif))
                    .foregroundColor(inkColor.opacity(showResult && !isCorrect && !isSelected ? 0.4 : 1))
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(bgColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(borderColor, lineWidth: showResult && isCorrect ? 2 : 1.5)
                    )
                    .shadow(color: .black.opacity(0.03), radius: 6, y: 2)
            )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.hasAnswered)
        .animation(.spring(response: 0.3), value: viewModel.hasAnswered)
    }
    
    private func optionLetter(_ index: Int) -> String {
        let letters = ["a.circle", "b.circle", "c.circle", "d.circle"]
        return index < letters.count ? letters[index] : "circle"
    }
    
    private func explanationCard(_ question: MCQuestion) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(stackColor)
                .padding(.top, 2)
            
            Text(question.explanation)
                .font(.system(size: 13, design: .serif))
                .foregroundColor(inkColor.opacity(0.8))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(stackColor.opacity(0.06))
        )
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}


// MARK: - Results View
@available(iOS 26.0, *)
extension QuizView {
    
    private var resultsView: some View {
        ScrollView {
            VStack(spacing: 30) {
                Spacer().frame(height: 20)
                
                // Score circle
                ZStack {
                    Circle()
                        .stroke(stackColor.opacity(0.12), lineWidth: 10)
                        .frame(width: 150, height: 150)
                    
                    Circle()
                        .trim(from: 0, to: Double(viewModel.score) / Double(viewModel.questions.count))
                        .stroke(
                            scoreGradient,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 150, height: 150)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 4) {
                        Text("\(viewModel.scorePercentage)%")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(scoreColor)
                        
                        Text("\(viewModel.score)/\(viewModel.questions.count)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Message
                VStack(spacing: 8) {
                    Text(scoreTitle)
                        .font(.system(.title2, design: .serif).bold())
                        .foregroundColor(inkColor)
                    
                    Text(scoreSubtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                // Stats row
                HStack(spacing: 20) {
                    statCard(icon: "checkmark.circle.fill", value: "\(viewModel.score)", label: "Correct", color: .green)
                    statCard(icon: "xmark.circle.fill", value: "\(viewModel.questions.count - viewModel.score)", label: "Incorrect", color: .red)
                    statCard(icon: "list.number", value: "\(viewModel.questions.count)", label: "Total", color: stackColor)
                }
                .padding(.horizontal, 20)
                
                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        viewModel.restartQuiz()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Retry Same Quiz")
                                .font(.system(.headline, design: .serif))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(stackColor)
                        )
                    }
                    
                    Button {
                        viewModel.backToSetup()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                            Text("Generate New Quiz")
                                .font(.system(.headline, design: .serif))
                        }
                        .foregroundColor(stackColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(stackColor, lineWidth: 1.5)
                                )
                        )
                    }
                    
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.system(.subheadline, design: .serif).bold())
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 5)
                }
                .padding(.horizontal, 30)
                
                Spacer().frame(height: 30)
            }
        }
    }
    
    private func statCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(inkColor)
            
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
    }
    
    private var scoreColor: Color {
        if viewModel.scorePercentage >= 80 { return .green }
        if viewModel.scorePercentage >= 50 { return .orange }
        return .red
    }
    
    private var scoreGradient: LinearGradient {
        if viewModel.scorePercentage >= 80 {
            return LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        if viewModel.scorePercentage >= 50 {
            return LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        return LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    private var scoreTitle: String {
        if viewModel.scorePercentage >= 90 { return "Excellent!" }
        if viewModel.scorePercentage >= 80 { return "Great Job!" }
        if viewModel.scorePercentage >= 60 { return "Good Effort!" }
        if viewModel.scorePercentage >= 40 { return "Keep Practicing!" }
        return "Don't Give Up!"
    }
    
    private var scoreSubtitle: String {
        if viewModel.scorePercentage >= 80 { return "You have a strong grasp of this material." }
        if viewModel.scorePercentage >= 50 { return "You're getting there. Review the topics you missed." }
        return "Consider reviewing your materials and try again."
    }
}


// MARK: - Question Count Chip
struct QuestionCountChip: View {
    let count: Int
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("\(count)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(isSelected ? .white : color)
                .frame(width: 50, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isSelected ? color : color.opacity(0.08))
                        .shadow(color: isSelected ? color.opacity(0.3) : .clear, radius: 6, y: 3)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.08 : 1.0)
    }
}


// MARK: - Orbit Animation
struct OrbitModifier: ViewModifier {
    let speed: Double
    @State private var rotation: Double = 0
    
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: speed).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}
