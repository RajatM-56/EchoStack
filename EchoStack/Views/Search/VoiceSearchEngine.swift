import SwiftUI
import Speech
import AVFoundation
import SwiftData


@available(iOS 17.0, *)
struct VoiceSearchView: View {
    @Environment(\.dismiss) var dismiss
    
    let allStacks: [SubjectStack]
    var onMatchFound: (SubjectStack) -> Void
    
    @State private var speechManager = SpeechRecognizerManager()
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            Color(red: 0.98, green: 0.97, blue: 0.95)
                .ignoresSafeArea()
            
            VStack(spacing: 25) {
                Text(speechManager.isRecording ? "Listening..." : "Finished Listening")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    .padding(.top, 30)
                
                ZStack {
                    Circle()
                        .stroke(Color.orange.opacity(0.3), lineWidth: 4)
                        .frame(width: 90, height: 90)
                        .scaleEffect(speechManager.isRecording ? pulseScale : 1.0)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 70, height: 70)
                        .shadow(color: .black.opacity(0.1), radius: 10)
                    
                    Image(systemName: speechManager.isRecording ? "mic.fill" : "mic.slash.fill")
                        .font(.title)
                        .foregroundColor(speechManager.isRecording ? .orange : .gray)
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                        pulseScale = 1.2
                    }
                }
                
                Text(speechManager.transcript.isEmpty ? "Say a subject name..." : "\"\(speechManager.transcript)\"")
                    .font(.system(.title2, design: .serif).italic())
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 20) {
                    Button("CANCEL") {
                        speechManager.stopRecording()
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                    
                    Button("DONE") {
                        speechManager.stopRecording()
                        performSearch()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    // Optional: Disable the Done button if no speech was detected
                    .disabled(speechManager.transcript.isEmpty)
                }
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                speechManager.startRecording()
            }
        }
        .onDisappear {
            speechManager.stopRecording()
        }
    }
    
    private func performSearch() {
        let text = speechManager.transcript
        guard !text.isEmpty else {
            dismiss()
            return
        }
        
        let lowercasedText = text.lowercased()
        
        if let match = allStacks.first(where: {
            let title = $0.title.lowercased()
            return lowercasedText.contains(title) || title.contains(lowercasedText)
        }) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onMatchFound(match)
        } else {
            // Optional: Provide feedback if no match is found before dismissing
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        
        dismiss()
    }
}

import SwiftUI
import Speech
import AVFoundation

@available(iOS 17.0, *)
@Observable
@MainActor
final class SpeechRecognizerManager {
    var transcript: String = ""
    var isRecording: Bool = false
    
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    func startRecording() {
        Task { await start() }
    }
    
    private func start() async {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            self.transcript = "<< Recognizer is unavailable >>"
            return
        }
        
        do {
            guard await SFSpeechRecognizer.hasAuthorizationToRecognize() else {
                self.transcript = "<< Not authorized to recognize speech >>"
                return
            }
            guard await AVAudioSession.sharedInstance().hasPermissionToRecord() else {
                self.transcript = "<< Not permitted to record audio >>"
                return
            }
            
            self.stopRecording()
            
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            self.recognitionRequest = request

            try Self.configureAndStartEngine(engine: audioEngine, request: request)
            

            self.recognitionTask = Self.startRecognitionTask(recognizer: recognizer, request: request, manager: self)
            
            self.isRecording = true
            
        } catch {
            self.stopRecording()
            self.transcript = "<< \(error.localizedDescription) >>"
        }
    }
    
    
    nonisolated private static func configureAndStartEngine(engine: AVAudioEngine, request: SFSpeechAudioBufferRecognitionRequest) throws {
        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.removeTap(onBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }
        
        engine.prepare()
        try engine.start()
    }
    
    nonisolated private static func startRecognitionTask(recognizer: SFSpeechRecognizer, request: SFSpeechAudioBufferRecognitionRequest, manager: SpeechRecognizerManager) -> SFSpeechRecognitionTask {

        return recognizer.recognitionTask(with: request) { result, error in
            manager.handleRecognition(result: result, error: error)
        }
    }
    
    nonisolated private func handleRecognition(result: SFSpeechRecognitionResult?, error: Error?) {
        let isFinal = result?.isFinal ?? false
        let hasError = error != nil
        let text = result?.bestTranscription.formattedString
        
        Task { @MainActor in
            if let text = text {
                self.transcript = text
            }
            if isFinal || hasError {
                self.stopRecording()
            }
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
    }
}

@available(iOS 17.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension SFSpeechRecognizer {
    static func hasAuthorizationToRecognize() async -> Bool {
        await withCheckedContinuation { continuation in
            requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}

@available(iOS 17.0, macOS 11.0, tvOS 14.0, watchOS 7.0, *)
extension AVAudioSession {
    func hasPermissionToRecord() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { authorized in
                continuation.resume(returning: authorized)
            }
        }
    }
}
