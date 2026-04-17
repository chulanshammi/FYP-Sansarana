# Sansarana - Comprehensive Project Documentation

## Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Project Structure](#project-structure)
4. [Models Layer](#models-layer)
5. [Services Layer](#services-layer)
6. [ViewModels Layer](#viewmodels-layer)
7. [Views Layer](#views-layer)
8. [AR Detection Pipeline](#ar-detection-pipeline)
9. [Foundation Models Chat System](#foundation-models-chat-system)
10. [3D Gaussian Splat Rendering](#3d-gaussian-splat-rendering)
11. [Data Persistence](#data-persistence)
12. [Dependencies](#dependencies)
13. [Key Design Decisions](#key-design-decisions)
14. [Build & Deployment](#build--deployment)

---

## Project Overview

**Sansarana** is an iOS augmented reality (AR) application built with SwiftUI that serves as an intelligent guide to the ancient Buddhist statues at **Gal Viharaya** (Rock Temple), a UNESCO World Heritage Site in Polonnaruwa, Sri Lanka. The temple contains three 12th-century granite Buddha statues carved from a single boulder during King Parakramabahu I's reign (1153-1186 CE).

### Core Features

- **Real-time statue detection** using a custom CoreML object detection model (`StatueDetection.mlmodel`) that identifies three statues: Seated Buddha, Standing Buddha, and Reclining Buddha
- **AR annotation overlays** showing interactive information points on detected statues with multiple positioning approaches (screen-space, 3D anchored, calibrated)
- **AI-powered chat guide** using Apple's Foundation Models framework for on-device, privacy-preserving conversations about each statue
- **3D Gaussian Splat viewer** for detailed examination of high-fidelity 3D reconstructions of each statue using MetalSplatter
- **Visit history tracking** for recording and reviewing past site visits

### Supported Statues

| Statue | Height | Description |
|--------|--------|-------------|
| Seated Buddha | ~4.6m (15ft) | Dhyana Mudra meditation posture, lotus throne |
| Standing Buddha | ~7m (23ft) | Crossed arms, debated as Buddha or Ananda |
| Reclining Buddha | ~14m (46ft) | Parinirvana pose, one of largest in SE Asia |

---

## Architecture

The application follows the **MVVM (Model-View-ViewModel)** pattern with a dedicated **Services** layer for data access and business logic.

```
┌─────────────────────────────────────────────────────┐
│                    Views Layer                        │
│  (SwiftUI Views, UIViewRepresentable wrappers)       │
├─────────────────────────────────────────────────────┤
│                 ViewModels Layer                      │
│  (@MainActor ObservableObject classes)               │
├─────────────────────────────────────────────────────┤
│                  Services Layer                       │
│  (Stateless helpers, persistence, knowledge base)    │
├─────────────────────────────────────────────────────┤
│                   Models Layer                        │
│  (Value types: enums, structs, Codable types)        │
└─────────────────────────────────────────────────────┘
```

### Concurrency Model

- All ViewModels are `@MainActor` isolated to ensure safe UI state updates
- Background work (CoreML detection) runs on a dedicated `DispatchQueue` with `nonisolated(unsafe)` for cross-isolation data access
- `Task.sleep` is preferred over `DispatchQueue.main.asyncAfter` for async delays
- Foundation Models calls use `async/await` natively

---

## Project Structure

```
Sansarana/
├── SansaranaApp.swift              # @main app entry point
├── SansaranaTheme.swift            # Brand colours, gradients (saffronGold, heritageBrown, etc.)
├── StatueDetection.mlmodel         # CoreML object detection model
├── Assets.xcassets/                # Image assets, AR reference images
│
├── Models/
│   ├── Statue.swift                # Core Statue enum, Annotation, AppTab, ChatMessage, PlaceVisit
│   ├── Statue+Annotations.swift    # Per-statue curated annotation data (position, content, facts)
│   ├── Statue+SplatConfig.swift    # Per-statue 3D viewer configuration (camera, rotation, scale)
│   └── StatueDetectionModels.swift # StatueDetectionResult, AnnotationPoint, CalibratedPosition, DevAnchorData, DevAnchorStore
│
├── Services/
│   ├── KnowledgeManager.swift      # System instruction formatting for Foundation Models
│   ├── StatueKnowledge.swift       # Curated knowledge base (history, description, facts per statue)
│   ├── StatueKnowledgeTool.swift   # Foundation Models Tool protocol conformance for on-demand knowledge lookup
│   └── VisitHistoryService.swift   # UserDefaults persistence for visit history
│
├── ViewModels/
│   ├── ARViewModel.swift           # AR session management, CoreML detection, annotation state
│   ├── ChatViewModel.swift         # Foundation Models chat session, message management
│   └── VisitHistoryViewModel.swift # Visit history display and persistence
│
├── Views/
│   ├── ContentView.swift           # Root view (SplatView, MetalKitView UIViewRepresentable)
│   ├── ARCameraView.swift          # Main AR camera with all overlays, tab navigation
│   ├── ChatView.swift              # Chat interface with suggestion chips, context usage indicator
│   ├── DetailView.swift            # 3D Gaussian Splat viewer with config controls and annotation info
│   ├── HistoryView.swift           # Visit history list with cards and detail sheets
│   ├── BottomTabBar.swift          # Custom tab bar (AR, Chat, History)
│   ├── BoundingBoxOverlay.swift    # Real-time bounding box rendering for detections
│   ├── AnnotationDotsOverlay.swift # Screen-space annotation dot indicators
│   ├── AnnotationCardsOverlay.swift# Expandable annotation info cards in AR view
│   ├── AnchorPlacementOverlay.swift# 3D anchor placement UI for annotation positioning
│   ├── CalibrationOverlay.swift    # Manual calibration interface for annotation offsets
│   ├── DeveloperModeOverlay.swift  # Developer tools for anchor placement/saving
│   └── StatueInfoCard.swift        # Statue information display card
│
└── Splats/                         # 3D Gaussian Splat PLY files
    ├── cleaned_seated_statue.ply
    ├── cleaned_standing_statue.ply
    └── cleaned_reclining_statue.ply
```

---

## Models Layer

### `Statue.swift`

The core data model file containing all shared value types:

- **`Statue`** — `enum: String, Codable, CaseIterable, Identifiable` with cases `.seatedBuddha`, `.standingBuddha`, `.recliningBuddha`. Provides computed properties: `title`, `subtitle` (Pali name), `description`, `height`, `width`.

- **`Annotation`** — `struct: Identifiable, Codable` representing an information point on a statue with `title`, `subtitle`, `position3D` (SIMD3<Float>), and `content: AnnotationContent`.

- **`AnnotationContent`** — `struct: Codable` with `title`, `description`, `facts: [String]`, `images: [String]`.

- **`AppTab`** — `enum` with cases `.ar`, `.chat`, `.history` for tab navigation.

- **`ChatMessage`** — `struct: Identifiable, Equatable` with `content: String`, `isUser: Bool`, `timestamp: Date`.

- **`SuggestionPrompt`** — `enum: String, CaseIterable` with pre-written chat prompts like "Tell me about this statue".

- **`PlaceVisit`** — `struct: Identifiable, Equatable` representing a site visit with `placeName`, `location`, `visitDate`, `artifactsSeen: [Statue]`, `verified: Bool`.

### `Statue+Annotations.swift`

Extension on `Statue` providing a computed `annotations: [Annotation]` property with curated data for each statue. Each statue has 3-4 annotated points with 3D positions, titles, descriptions, and educational facts. Example points: "Ushnisha (Crown Protuberance)", "Dhyana Mudra (Meditation Gesture)", "Lotus Petal Throne Base".

### `Statue+SplatConfig.swift`

Extension on `Statue` providing per-statue 3D viewer defaults:
- `splatFileName` — PLY file name (e.g., "cleaned_seated_statue.ply")
- `defaultCenterOffset`, `defaultBaseRotation`, `defaultCameraPosition` — SIMD3<Float> values
- `defaultScale`, `defaultZoomScale` — Float values
- `defaultModelRotation`, `defaultModelPosition` — SIMD3<Float> values
- `defaultCameraOrbit`, `defaultGestureRotation` — SIMD2<Float> values

### `StatueDetectionModels.swift`

Supporting types for the AR detection system:

- **`StatueDetectionResult`** — `struct: Identifiable` with `statue: Statue`, `boundingBox: CGRect` (normalized Vision coordinates), `confidence: Float`, `screenRect: CGRect` (screen pixels).

- **`AnnotationPoint`** — `struct: Identifiable` for relative annotation positioning within a bounding box (`relativeX/Y: CGFloat` in 0.0-1.0 range).

- **`Statue.annotationPoints`** — Extension providing per-statue relative annotation positions.

- **`CalibratedPosition`** — `struct: Codable` storing a calibration offset (SIMD3<Float>) for an annotation label. Custom Codable implementation for SIMD3 encoding.

- **`DevAnchorData`** — `struct: Codable` storing developer-placed anchor offsets from a reference point.

- **`DevAnchorStore`** — Utility struct for persisting/loading developer anchors via UserDefaults.

---

## Services Layer

### `KnowledgeManager.swift`

An `enum` (namespace, no instances) that formats system instructions for the Foundation Models chat session. Provides:

- `getSystemInstructionsWithTool(for:)` — Token-efficient instructions for use with `StatueKnowledgeTool` (tool calling approach, ~200-300 tokens)
- `getSystemInstructionsWithFullKnowledge(for:)` — Full knowledge embedding fallback (~700-800 tokens)
- `getWelcomeMessage(for:)` — Per-statue welcome messages
- `getUnavailabilityMessage(for:)` — User-friendly messages for various unavailability states (device not eligible, Apple Intelligence not enabled, model not ready)
- `generateContextSummary(from:)` — Summarizes conversation for context overflow recovery

### `StatueKnowledge.swift`

A `struct` (namespace) containing the curated knowledge base as static string properties and methods. Organized by category:

- `generalKnowledge` — General Gal Viharaya information (~150 words)
- Per-statue knowledge accessed via `getSection(for:category:)` using `InfoCategory` enum:
  - `.generalHistory` — Site history
  - `.physicalDescription` — Appearance and features
  - `.buddhistSignificance` — Spiritual and religious meaning
  - `.artisticDetails` — Sculptural techniques and style
  - `.dimensions` — Physical measurements
  - `.interestingFacts` — Notable details and trivia

### `StatueKnowledgeTool.swift`

Implements Apple's Foundation Models `Tool` protocol for on-demand knowledge retrieval. This is more token-efficient than embedding all knowledge upfront because the LLM only fetches what it needs per question (~100-150 tokens at a time vs ~800 upfront).

- Conforms to `Tool` with `@Generable struct Arguments` containing a `ToolInfoCategory` enum
- The `call(arguments:)` method converts the tool category to `InfoCategory` and looks up the relevant knowledge section
- Marked `@MainActor` to satisfy actor isolation requirements

### `VisitHistoryService.swift`

A `struct` providing persistence for visit history via UserDefaults:

- `loadVisits() -> [PlaceVisit]` — Loads saved visits or returns sample data
- `saveVisit(_:)` — Persists a new visit
- Uses a private `SavedVisit: Codable` type as a transport layer to handle the non-Codable `PlaceVisit` (which contains `[Statue]` arrays that need raw value conversion)

---

## ViewModels Layer

### `ARViewModel.swift`

The primary ViewModel managing the AR detection pipeline. `@MainActor class: ObservableObject`.

**Key Published State:**
- `detectedStatue: Statue?` — Legacy single-statue detection (reference image path)
- `isStatueDetected: Bool` — Whether any statue is currently detected
- `detectedStatues: [StatueDetectionResult]` — All current object detection results
- `primaryStatue: Statue?` — Highest-confidence detection
- `currentAnnotations: [Annotation]` — Annotations for the primary statue
- `classificationConfidence: Float` — Current detection confidence
- `boundingBoxStable: Bool` — Whether the bounding box position is stable (for anchor placement)
- `calibrationMode: Bool`, `calibratedPositions`, `developerMode`, `devPlacedAnchors`, etc.

**Detection Pipeline:**
1. `setupObjectDetection()` — Loads `StatueDetection.mlmodel` as `VNCoreMLModel`, creates `VNCoreMLRequest`
2. `classifyPixelBuffer(_ pixelBuffer: CVPixelBuffer)` — Called on every AR frame (throttled to ~2fps). Accepts only the extracted pixel buffer (not the full `ARFrame`) to prevent ARFrame retention leaks that cause resource pressure and system kills. Dispatches to a background `DispatchQueue`. Uses `nonisolated(unsafe)` for the pixel buffer to avoid Sendable warnings.
3. `handleDetection(request:error:)` — Processes Vision results on background queue, then dispatches to MainActor to update UI state
4. Grace period: clears detection state after 4 consecutive frames (~2s) with no detections to prevent flicker

**Annotation Approaches:**
- Approach 1: Screen-space annotation dots positioned relative to bounding box
- Approach 2: 3D AR anchors placed via raycasting from stable bounding box
- Approach 3: Manual calibration with persistent offsets
- Developer Mode: Tap-to-place anchors with reference point system, persisted to UserDefaults

### `ChatViewModel.swift`

Manages the Foundation Models chat session. `@MainActor class: ObservableObject`.

**Key Published State:**
- `messages: [ChatMessage]` — Conversation history
- `inputText: String` — Current input field text
- `isGenerating: Bool` — Whether the model is generating a response
- `isModelAvailable: Bool` — Foundation Models availability
- `unavailabilityReason: String?` — User-friendly explanation if unavailable
- `showContextWarning: Bool` / `contextUsagePercentage: Double` — Context window usage tracking

**Session Management:**
1. `checkModelAvailability()` — Checks `SystemLanguageModel.default.availability`
2. `configureSession(for:)` — Creates `LanguageModelSession` with either tool calling (default, more efficient) or full knowledge embedding
3. `sendMessageStreaming()` — Sends user message, gets response via `session.respond(to:)`, handles tool calling round-trips automatically
4. `handleContextOverflow()` — On context window exhaustion, creates new session with conversation summary, retries the failed message
5. Token estimation: rough approximation at 1 token ≈ 4 characters, tracks against 4096 max context window

### `VisitHistoryViewModel.swift`

Simple ViewModel for visit history. `@MainActor final class: ObservableObject`.

- `visits: [PlaceVisit]` / `selectedVisit: PlaceVisit?` — Published state
- `loadVisits()` — Delegates to `VisitHistoryService`
- `recordVisit(_:)` — Saves and reloads

---

## Views Layer

### `ContentView.swift`

The root view containing:
- `ContentView` — Simply renders `ARCameraView()`
- `SplatView` — SwiftUI wrapper for the MetalKit splat renderer with configurable camera, rotation, scale, and gesture bindings
- `MetalKitView` — `UIViewRepresentable` that creates and manages an `MTKView` with a `SplatRenderer`. Handles:
  - View matrix computation from camera position, rotation, gestures
  - Projection matrix with perspective projection
  - Model transform matrix (translation, rotation, scale, center offset)
  - Metal command buffer encoding and presentation
  - MVP matrix callback for annotation overlay positioning

### `ARCameraView.swift`

The main AR experience view. Contains:
- `ARViewContainer` — `UIViewRepresentable` wrapping `ARView` with AR session delegate. The `session(_:didUpdate:)` delegate extracts the pixel buffer from each `ARFrame` immediately and passes only the `CVPixelBuffer` to the detection pipeline, ensuring `ARFrame` objects are released promptly and preventing memory pressure.
- AR configuration with `ARWorldTrackingConfiguration` including image detection from `StatueReferences` resource group
- Overlay composition: `BoundingBoxOverlay`, `AnnotationDotsOverlay`, `AnnotationCardsOverlay`, `AnchorPlacementOverlay`, `DeveloperModeOverlay`, `CalibrationOverlay`
- Navigation to `ChatView`, `HistoryView`, `DetailView` via sheets and fullScreenCovers
- `BottomTabBar` for tab switching
- `StatueInfoCard` for detection result display

### `DetailView.swift`

The 3D Gaussian Splat viewer for detailed statue examination:
- Loads PLY files using `AutodetectSceneReader(url).readAll()` → `MetalBuffer<EncodedSplatPoint>` (with `ensureCapacity` + `append`) → `SplatChunk(splats:)` → `await addChunk(_:)`
- Full gesture support: drag rotation, pinch zoom, camera orbit
- Configuration controls panel (`ModelConfigControls`) for adjusting camera position, rotation, scale, model position
- Annotation info sections with expandable facts
- UserDefaults persistence for viewer defaults per statue (`DevAnchorStore` pattern)
- Copy-to-clipboard for configuration values

### `ChatView.swift`

Chat interface featuring:
- Foundation Models availability check with graceful fallback messaging
- Scrolling message list with user/assistant bubble styling
- Suggestion chips for common questions
- Context usage progress indicator
- Input field with send button
- Session configuration on appear based on detected statue

### `HistoryView.swift`

Visit history using the new MVVM pattern:
- `@StateObject private var viewModel = VisitHistoryViewModel()` — proper ViewModel injection
- `PlaceVisitCard` — Visual card for each visit showing place name, date, artifacts seen
- `VisitDetailView` — Sheet showing detailed visit information
- `EmptyHistoryView` — Placeholder when no visits exist
- Loads visits on appear via `viewModel.loadVisits()`

### Overlay Views

- **`BoundingBoxOverlay`** — Renders real-time bounding boxes with confidence labels, tappable for statue selection
- **`AnnotationDotsOverlay`** — Small dot indicators at annotation positions relative to bounding box
- **`AnnotationCardsOverlay`** — Expandable information cards at 3D-anchored annotation positions
- **`AnchorPlacementOverlay`** — UI for placing 3D anchors at annotation points via raycasting
- **`CalibrationOverlay`** — Manual offset adjustment interface with 3-axis sliders
- **`DeveloperModeOverlay`** — Developer tools for persistent anchor placement with save/clear/export
- **`StatueInfoCard`** — Detection result card showing statue name, subtitle, confidence, action buttons
- **`BottomTabBar`** — Custom bottom tab bar with AR, Chat, and History tabs

---

## AR Detection Pipeline

### Flow

```
ARSession Frame (60fps)
        │
        ▼ (throttled to ~2fps)
Extract frame.capturedImage (CVPixelBuffer)
   ↳ ARFrame released immediately to prevent retention leak
        │
        ▼
ARViewModel.classifyPixelBuffer(_:)
        │
        ▼ (background DispatchQueue)
VNImageRequestHandler.perform([VNCoreMLRequest])
        │
        ▼
StatueDetection.mlmodel inference
        │
        ▼
VNRecognizedObjectObservation results
        │
        ▼ (filtered > 0.7 confidence)
handleDetection(request:error:)
        │
        ▼ (Task @MainActor)
Update published state:
- detectedStatues (all results)
- primaryStatue (highest confidence)
- boundingBoxStable (3+ stable frames)
- Grace period (4 frames before clearing)
```

### Detection Model

- **File:** `StatueDetection.mlmodel` (CoreML)
- **Input:** Camera pixel buffer (CVPixelBuffer)
- **Output:** `VNRecognizedObjectObservation` with labels: "seated", "standing", "reclining"
- **Confidence threshold:** 0.7 (70%)
- **Compute units:** `.all` (Neural Engine + GPU + CPU)

### Annotation Positioning Approaches

The app implements three approaches for positioning annotations on detected statues:

1. **Screen-space (Approach 1):** Relative positions within the bounding box (0.0-1.0). Simple but moves with camera.

2. **3D Anchored (Approach 2):** Raycast from bounding box center to place AR anchors in 3D space. Requires stable bounding box detection (3+ consecutive frames). More stable but depends on accurate raycasting.

3. **Developer Mode (Persistent):** Tap-to-place anchors stored as offsets from a reference point. Persisted to UserDefaults via `DevAnchorStore`. Independent of AR session — only requires statue re-detection.

---

## Foundation Models Chat System

### Architecture

```
ChatView (UI)
    │
    ▼
ChatViewModel
    │
    ├── LanguageModelSession (Apple Foundation Models)
    │       │
    │       ├── System Instructions (from KnowledgeManager)
    │       │
    │       └── StatueKnowledgeTool (Tool protocol)
    │               │
    │               └── StatueKnowledge (knowledge base)
    │
    └── Context Management
            ├── Token estimation (~4 chars/token)
            ├── Usage tracking (4096 max window)
            └── Overflow recovery (session refresh + summary)
```

### Token Efficiency Strategy

The app uses a **tool calling** approach by default:
- System instructions are minimal (~200-300 tokens): just the role description and statue context
- The `StatueKnowledgeTool` is registered with the session
- When the user asks a question, the model calls the tool to fetch only the relevant knowledge section (~100-150 tokens)
- This is more efficient than embedding all knowledge upfront (~800+ tokens)

### Fallback: Full Knowledge Embedding

If tool calling is disabled (`useToolCalling = false`), all knowledge for the statue is embedded in the system instructions. This uses more tokens but avoids tool calling latency.

### Context Overflow Handling

When the context window is exhausted (`LanguageModelSession.GenerationError.exceededContextWindowSize`):
1. Generate a conversation summary from existing messages
2. Create a new session with the summary appended to system instructions
3. Retry the failed user message on the new session
4. Show user a "refreshed memory" message

---

## 3D Gaussian Splat Rendering

### Pipeline

```
PLY File (Splats/)
    │
    ▼
SplatIO.AutodetectSceneReader(url).readAll()
    │
    ▼
[SplatPoint] array
    │
    ▼
MetalBuffer<EncodedSplatPoint>(device:)
  ├── ensureCapacity(points.count)
  └── append(points.map { EncodedSplatPoint($0) })
    │
    ▼
SplatChunk(splats: buffer)
    │
    ▼
await SplatRenderer.addChunk(_:)
    │
    ▼
MetalKitView (UIViewRepresentable)
    │
    ▼
MTKView rendering at 60fps
```

### Camera System

The 3D viewer uses a configurable camera system with:
- **Camera position:** World-space SIMD3<Float>
- **Center offset:** Model center correction
- **Base rotation:** Initial model orientation
- **Gesture rotation:** User drag input (X/Y)
- **Zoom scale:** Pinch gesture input
- **Camera orbit:** Orbital camera movement

All transforms are composed into a Model-View-Projection (MVP) matrix in the MetalKitView coordinator's `draw(in:)` method.

### Per-Statue Configurations

Each statue has hand-tuned default values in `Statue+SplatConfig.swift`:
- Seated Buddha: Upside-down base rotation (π around X), close camera (z=1.0)
- Standing Buddha: Rotated 180° around Y, medium distance (z=4.0)
- Reclining Buddha: Slight tilt, rotated 90° around Y, far camera (z=5.0), 0.8x scale

---

## Data Persistence

All persistence uses **UserDefaults** (appropriate for the small data volume):

| Key | Type | Purpose |
|-----|------|---------|
| `calibratedPositions` | `[String: [CalibratedPosition]]` | Annotation calibration offsets per statue |
| `devAnchors_{statueRawValue}` | `[DevAnchorData]` | Developer-placed anchor offsets |
| `visitHistory` | `[SavedVisit]` | Place visit records |
| `viewer_{statue}_{property}` | Various | 3D viewer defaults per statue |

---

## Dependencies

| Package | Purpose |
|---------|---------|
| **MetalSplatter** | 3D Gaussian Splat rendering (SplatRenderer, SplatChunk, MetalBuffer) |
| **SplatIO** | PLY file reading (AutodetectSceneReader, SplatPoint, EncodedSplatPoint) |

### System Frameworks

| Framework | Purpose |
|-----------|---------|
| SwiftUI | UI framework |
| ARKit | Augmented reality session, world tracking |
| RealityKit | AR view, anchor management |
| CoreML | ML model inference |
| Vision | Image analysis, object detection |
| Metal / MetalKit | GPU rendering for splat viewer |
| FoundationModels | On-device LLM (Apple Intelligence) |
| Combine | ObservableObject / @Published support |

---

## Key Design Decisions

### 1. MVVM with Services

Models are pure value types (structs/enums). ViewModels are `@MainActor ObservableObject` classes that own business logic. Services are stateless structs for data access. This ensures clean separation and testability.

### 2. Swift Concurrency Throughout

- `async/await` for all asynchronous operations
- `Task.sleep` instead of `DispatchQueue.main.asyncAfter`
- `@MainActor` on all ViewModels
- `nonisolated(unsafe)` for cross-isolation data access in the detection pipeline
- `@preconcurrency import Vision` for backward-compatible Vision framework usage

### 3. Tool Calling for Token Efficiency

The Foundation Models integration uses a tool calling approach rather than embedding full knowledge. This reduces base token usage by ~500-600 tokens per session, leaving more room for conversation within the 4096-token context window.

### 4. Multiple Annotation Approaches

Rather than choosing a single annotation positioning method, the app implements three approaches that can be used depending on conditions — screen-space for quick feedback, 3D anchored for stability, and developer mode for persistent placement.

### 5. Grace Period for Detection Stability

A 4-frame (~2 second) grace period before clearing detection state prevents UI flicker when the camera briefly loses sight of a statue.

### 6. Modern MetalSplatter API

Uses the current `SplatChunk`/`addChunk` API instead of the deprecated `read(from:)` method, ensuring forward compatibility with MetalSplatter updates.

---

## Build & Deployment

- **Platform:** iOS 26.0+
- **Language:** Swift 6.0+
- **IDE:** Xcode 26+
- **Required device capabilities:** ARKit-compatible device with LiDAR (recommended), A12+ chip
- **Apple Intelligence requirement:** iPhone 16+ or iPad with M-series chip for Foundation Models chat feature
- **Camera permission required** for AR functionality
- **No network access required** — all ML inference and chat runs on-device

### Build

Open `Sansarana.xcodeproj` in Xcode and build for a physical iOS device (AR features do not work in Simulator).

### PLY Files

The 3D Gaussian Splat `.ply` files must be included in the app bundle under the `Splats/` directory:
- `cleaned_seated_statue.ply`
- `cleaned_standing_statue.ply`
- `cleaned_reclining_statue.ply`

### AR Reference Images

AR reference images for statue recognition are configured in `Assets.xcassets/StatueReferences.arresourcegroup/`.
