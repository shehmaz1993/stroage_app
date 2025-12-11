# storage_app

Storage app is a  file management app, where a user can maintain their essential files in cloud.

## Getting Started

## Design Decisions and Architecture

### 1. State Management (Riverpod)
We chose **Riverpod** for reliable, testable state management. The `TransferNotifier` holds the list of `FileTransfer` objects, providing a single source of truth for the entire application, making UI updates declarative and efficient.

### 2. Architecture Separation (Clean Separation of Concerns)
* **Screens (UI):** Focused purely on rendering the current state (e.g., `HomeScreen` filters and displays the list).
* **Notifier (Business Logic):** Manages status transitions, controls user actions (pause/resume), and handles Riverpod state updates.
* **Service (Networking/Persistence):** Encapsulates external interactions (Dio for network calls, Persistence Service for local storage). This ensures the core logic is decoupled from external libraries.

### 3. Handling Pauses and Failures (Robustness)
A critical decision was to explicitly differentiate between a user **pause** and a **network failure**.
* **Custom Exception:** We introduced `TransferCancelledException` to specifically handle the cancellation signal sent by Dio during a pause.
* **Notifier Logic:** The `try...catch` blocks in the Notifier now ignore the `TransferCancelledException`, preventing a paused transfer from being incorrectly marked as `failed`.
* **Resumability:** The `startByte` parameter in the `TransferService` allows all transfers to resume from the last saved byte count, fulfilling the requirement for graceful handling of poor network conditions and retries.


## Running the Project

### Prerequisites
* Flutter SDK (Version 3.27.1 or higher)
* Dart SDK (Included with Flutter)
* A physical device or emulator (iOS or Android)

### Setup Steps

1.  **Unzip the file:**
    
2.  **Install Dependencies:**
    Open the terminal in the project root directory and run:
    ```
    flutter pub get
    ```
3.  **Run the App:**
    Ensure you have an active emulator or device connected, then run:
    ```
    flutter run
    ```

### Key Features to Test

1.  **Start a Transfer:** Initiate an upload/download and observe its status transition (`pending` -> `uploading`).
2.  **Pause/Resume:** Pause an active transfer. Verify that its status changes to **Paused** (not Failed) and that it appears in the **Paused & Pending** list. Resume the transfer to ensure it continues from the correct progress point.
3.  **Failure/Retry:** Simulate a network failure (e.g., disconnecting Wi-Fi mid-transfer). Verify the transfer status changes to **Failed**. Tap to resume/retry, and ensure it attempts to continue the transfer.