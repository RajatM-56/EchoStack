# EchoStack 📚

EchoStack is a native iOS app designed for college students who receive a large number of PDF and DOCX files for various subjects. These files often become scattered across different folders on their devices, making them difficult to locate when needed.

EchoStack provides a centralized space where students can upload their study materials and organize them into the appropriate folders with a single tap. This reduces the time students spend searching for study materials, especially during exam time, allowing them to focus more on studying.

---

## 🌟 Key Features

*   **Recursive Subject Stacks:** Create deeply nested folder hierarchies to map your exact college course structures.
*   **Voice Search Engine:** Hands-free document retrieval. Tap the microphone, speak a subject name, and the app transcribes the audio in real-time to locate your documents instantly.
*   **Interactive Organization:** Drag-and-drop mechanics to seamlessly move files between folders.
*   **Visual Stack Map:** A recursive UI tree component that visualizes your entire folder hierarchy at a glance.
*   **100% Offline Access:** Your study materials are always available. EchoStack uses a local persistence system, meaning zero reliance on internet connectivity or cloud servers.

---

## 🏗️ Technical Architecture

EchoStack follows a modern iOS architecture separating UI, Business Logic, and Data Persistence:

*   **Frontend (UI):** Built entirely declaratively using **SwiftUI**. Features recursive views to handle infinitely nested folder structures.
*   **Data Persistence:** Utilizes a custom JSON-based storage system leveraging `FileManager` and `Codable` (or `SwiftData`) to store the entire folder/file tree directly in the secure iOS App Sandbox.
*   **Speech & Audio:** Integrates `AVFoundation` for microphone audio capture and `SFSpeechRecognizer` for on-device, real-time speech-to-text processing.
*   **Document Preview:** Utilizes Apple's native `QuickLook` framework to render PDFs, DOCX, and images natively without third-party dependencies.

---

## ⚙️ System Requirements

### Functional
*   Infinite recursive folder creation ("Subject Stacks").
*   Real-time voice-to-text transcription for global folder search.
*   Drag-and-drop UI for reordering files and folders.
*   Native, in-app document previewing.

### Non-Functional
*   **Reliability:** 100% offline functionality.
*   **Privacy:** All audio processing and document storage remain strictly on-device within the App Sandbox.
*   **Performance:** Background thread serialization for data saving to prevent UI freezes on complex folder trees.

---

## 🚀 Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/RajatM-56/EchoStack.git
   ```
2. Open the project in **Xcode**.
3. Build and run on an iOS Simulator or a physical device (iOS 17.0+ required for some modern SwiftUI and Speech features).
4. *Note: Running on a physical device is recommended to fully test the Voice Search and microphone capabilities.*
