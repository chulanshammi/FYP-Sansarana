//
//  ARCameraView.swift
//  Sansarana
//
//  Created by Chulan Shammi on 2026-03-18.
//

import SwiftUI
import ARKit
import RealityKit

struct ARCameraView: View {
    @StateObject private var arViewModel = ARViewModel()
    @StateObject private var chatViewModel = ChatViewModel()
    @State private var selectedAnnotation: Annotation?
    @State private var selectedTab: AppTab = .ar
    @State private var showingChat = false
    @State private var showingHistory = false
    @State private var arView: ARView?
    
    /// Whether any overlay (sheet or fullScreenCover) is currently presented
    private var isOverlayPresented: Bool {
        showingChat || showingHistory || selectedAnnotation != nil
    }
    
    var body: some View {
        ZStack {
            // AR Camera View
            ARViewContainer(viewModel: arViewModel, arView: $arView)
                .edgesIgnoringSafeArea(.all)
            
            // Object Detection: Bounding boxes
            BoundingBoxOverlay(
                detections: arViewModel.detectedStatues,
                primaryStatue: arViewModel.primaryStatue,
                onSelect: { statue in
                    arViewModel.selectPrimaryStatue(statue)
                }
            )
            .allowsHitTesting(true)
            
            // Object Detection: Annotation dots (Approach 1 — screen-space)
            AnnotationDotsOverlay(
                detections: arViewModel.detectedStatues,
                primaryStatue: arViewModel.primaryStatue,
                upgradedPoints: arViewModel.anchoredPointLabels,
                onSelectAnnotation: { label in
                    // Find matching annotation from currentAnnotations.
                    if let annotation = arViewModel.currentAnnotations.first(where: { $0.title == label }) {
                        selectedAnnotation = annotation
                    }
                }
            )
            
            // Floating AR info cards (above dots, tracks 3D positions)
            if arViewModel.isStatueDetected {
                FloatingAnnotationCardsOverlay(
                    statue: arViewModel.primaryStatue,
                    annotations: arViewModel.currentAnnotations,
                    anchoredScreenPositions: arViewModel.annotationScreenPositions,
                    detections: arViewModel.detectedStatues,
                    selectedAnnotation: $selectedAnnotation
                )
                .allowsHitTesting(true)
            }
            
            // Developer Mode overlay (persistent anchor placement)
            if arViewModel.developerMode {
                DeveloperModeOverlay(
                    viewModel: arViewModel,
                    onRequestRaycast: { screenPoint in
                        guard let arView = arView else { return nil }
                        let results = arView.raycast(
                            from: screenPoint,
                            allowing: .estimatedPlane,
                            alignment: .any
                        )
                        if let hit = results.first {
                            let col = hit.worldTransform.columns.3
                            return SIMD3<Float>(col.x, col.y, col.z)
                        }
                        return nil
                    },
                    onEstablishReference: {
                        guard let arView = arView,
                              let statue = arViewModel.primaryStatue,
                              let detection = arViewModel.detectedStatues.first(where: { $0.statue == statue }) else {
                            arViewModel.devStatusMessage = "No statue detected. Point camera at the statue."
                            return
                        }
                        // Direct raycast from bbox center for reference establishment
                        let centerPoint = CGPoint(
                            x: detection.screenRect.midX,
                            y: detection.screenRect.midY
                        )
                        let results = arView.raycast(
                            from: centerPoint,
                            allowing: .estimatedPlane,
                            alignment: .any
                        )
                        if let hit = results.first {
                            let col = hit.worldTransform.columns.3
                            let worldPos = SIMD3<Float>(col.x, col.y, col.z)
                            arViewModel.setDevReference(worldPos)
                        } else {
                            arViewModel.devStatusMessage = "Raycast missed — move closer to the statue."
                        }
                    }
                )
            }
            
            // Overlay UI
            VStack {
                // Top Info Card — fixed position
                if let primaryStatue = arViewModel.primaryStatue {
                    StatueInfoCard(statue: primaryStatue)
                        .padding(.top, 60)
                        .padding(.horizontal, 16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                Spacer()
                
                // Bottom Tab Bar
                BottomTabBar(
                    selectedTab: $selectedTab,
                    isStatueDetected: arViewModel.isStatueDetected
                )
            }
            
            // Hidden developer mode toggle: triple-tap top-right corner
            VStack {
                HStack {
                    Spacer()
                    Color.clear
                        .frame(width: 60, height: 60)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 3) {
                            arViewModel.developerMode.toggle()
                            if !arViewModel.developerMode {
                                arViewModel.resetDeveloperMode()
                            }
                            print("📌 Developer mode: \(arViewModel.developerMode ? "ON" : "OFF")")
                        }
                }
                Spacer()
            }
        }
        .sheet(item: $selectedAnnotation) { annotation in
            DetailView(
                statue: arViewModel.primaryStatue ?? arViewModel.detectedStatue ?? .seatedBuddha,
                annotation: annotation
            )
        }
        .sheet(isPresented: $showingChat) {
            ChatView(
                chatViewModel: chatViewModel,
                statue: arViewModel.primaryStatue ?? arViewModel.detectedStatue
            )
        }
        .sheet(isPresented: $showingHistory) {
            HistoryView()
        }
        .onChange(of: isOverlayPresented) { _, presented in
            if presented {
                arView?.session.pause()
            } else {
                resumeARSession()
            }
        }
        .onChange(of: selectedTab) { _, newValue in
            switch newValue {
            case .chat:
                showingChat = true
                selectedTab = .ar
            case .history:
                showingHistory = true
                selectedTab = .ar
            case .ar:
                break
            }
        }
        .onChange(of: arViewModel.primaryStatue) { _, newStatue in
            if let statue = newStatue {
                Task {
                    await chatViewModel.configureSession(for: statue)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .annotationTapped)) { notification in
            if let annotation = notification.object as? Annotation {
                selectedAnnotation = annotation
            }
        }
    }
    
    /// Resumes the AR session with the existing configuration
    private func resumeARSession() {
        guard let arView = arView else { return }
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        
        if let referenceImages = ARReferenceImage.referenceImages(
            inGroupNamed: "StatueReferences",
            bundle: nil
        ) {
            configuration.detectionImages = referenceImages
            configuration.maximumNumberOfTrackedImages = 1
        }
        
        arView.session.run(configuration, options: [])
    }
}

// MARK: - AR View Container
struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: ARViewModel
    @Binding var arView: ARView?
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        
        // Configure AR session
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        
        // Load reference images for statue detection
        if let referenceImages = ARReferenceImage.referenceImages(
            inGroupNamed: "StatueReferences",
            bundle: nil
        ) {
            configuration.detectionImages = referenceImages
            configuration.maximumNumberOfTrackedImages = 1
        }
        
        arView.session.run(configuration)
        print("📷 AR session started — camera feed should be visible")
        
        // Set delegate
        context.coordinator.arView = arView
        arView.session.delegate = context.coordinator
        
        // Add tap gesture for annotation selection
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        arView.addGestureRecognizer(tapGesture)
        
        // Expose the ARView to the parent
        DispatchQueue.main.async {
            self.arView = arView
        }
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // Update screen size for coordinate conversion.
        let size = uiView.bounds.size
        if size != viewModel.screenSize {
            Task { @MainActor in
                viewModel.screenSize = size
            }
        }
        
        // Update annotations when they change
        context.coordinator.updateAnnotations(viewModel.currentAnnotations)
        
        // When bounding box is stable and a statue is detected:
        if viewModel.boundingBoxStable,
           let statue = viewModel.primaryStatue,
           let detection = viewModel.detectedStatues.first(where: { $0.statue == statue }) {
            
            if viewModel.hasDevAnchors(for: statue) && !viewModel.developerMode {
                // Developer anchors exist → restore them using bbox center raycast + offsets
                context.coordinator.restoreDevAnchors(
                    for: statue,
                    detection: detection,
                    arView: uiView
                )
            } else if !viewModel.hasCalibrationData(for: statue) && !viewModel.developerMode {
                // No dev anchors, no calibration → fall back to Approach 2 raycasts
                context.coordinator.performRaycastAnchoring(
                    for: statue,
                    detection: detection,
                    arView: uiView
                )
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }
    
    class Coordinator: NSObject, ARSessionDelegate {
        let viewModel: ARViewModel
        var arView: ARView?
        var annotationEntities: [String: AnchorEntity] = [:]
        
        /// Tracks which labels have already had raycasts attempted.
        private var raycastedLabels: Set<String> = []
        /// Tracks the last set of annotation IDs to detect changes.
        private var lastAnnotationIDs: Set<UUID> = []
        /// Throttle: last time we ran classifyFrame.
        private var lastClassifyTime: Date = .distantPast
        private let classifyInterval: TimeInterval = 0.5
        /// Throttle: last time we projected anchor positions to screen space.
        private var lastProjectionTime: Date = .distantPast
        private let projectionInterval: TimeInterval = 0.1 // ~10fps
        /// Whether dev anchors have been restored for the current detection cycle.
        private var devAnchorsRestored: Bool = false
        /// Throttle reference establishment to avoid repeated raycasts.
        private var lastReferenceAttemptTime: Date = .distantPast
        
        init(viewModel: ARViewModel) {
            self.viewModel = viewModel
        }
        
        // MARK: - ARSessionDelegate
        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            for anchor in anchors {
                if let imageAnchor = anchor as? ARImageAnchor {
                    handleImageDetection(imageAnchor)
                }
            }
        }
        
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            // Throttle object detection to 0.5s intervals.
            let now = Date()
            if now.timeIntervalSince(lastClassifyTime) >= classifyInterval {
                lastClassifyTime = now
                // Extract the pixel buffer immediately so the ARFrame can be released.
                let pixelBuffer = frame.capturedImage
                viewModel.classifyPixelBuffer(pixelBuffer)
            }
            
            // Project 3D anchor positions to screen space at ~10fps.
            if now.timeIntervalSince(lastProjectionTime) >= projectionInterval {
                lastProjectionTime = now
                projectAnchorPositions()
            }
        }
        
        // MARK: - Screen Projection
        
        /// Projects all raycast anchor positions to screen coordinates.
        private func projectAnchorPositions() {
            guard let arView = arView else { return }
            
            var positions: [String: CGPoint] = [:]
            
            for (key, anchorEntity) in annotationEntities {
                // Extract the label from the key
                let label: String
                if key.hasPrefix("raycast_") {
                    label = String(key.dropFirst("raycast_".count))
                } else if key.hasPrefix("dev_") {
                    label = String(key.dropFirst("dev_".count))
                } else {
                    continue
                }
                
                let worldPos = anchorEntity.position(relativeTo: nil)
                if let screenPoint = arView.project(worldPos) {
                    let bounds = arView.bounds
                    if bounds.contains(screenPoint) {
                        positions[label] = screenPoint
                    }
                }
            }
            
            Task { @MainActor [positions] in
                for (label, pos) in positions {
                    self.viewModel.updateAnnotationScreenPosition(label, position: pos)
                }
                let currentLabels = Set(positions.keys)
                let existingLabels = Set(self.viewModel.annotationScreenPositions.keys)
                for label in existingLabels.subtracting(currentLabels) {
                    self.viewModel.removeAnnotationScreenPosition(label)
                }
            }
        }
        
        // MARK: - Image Detection
        private func handleImageDetection(_ imageAnchor: ARImageAnchor) {
            guard arView != nil else { return }
            
            let statueName = imageAnchor.referenceImage.name ?? "unknown"
            
            Task { @MainActor in
                viewModel.handleStatueDetection(statueName, anchor: imageAnchor)
                placeAnnotations(for: statueName, imageAnchor: imageAnchor)
            }
        }
        
        // MARK: - Annotation Placement (Reference Image path)
        func placeAnnotations(for statueName: String, imageAnchor: ARImageAnchor) {
            guard let arView = arView else { return }
            
            annotationEntities.values.forEach { $0.removeFromParent() }
            annotationEntities.removeAll()
            
            let annotations = viewModel.currentAnnotations
            
            for annotation in annotations {
                let anchorEntity = AnchorEntity(world: imageAnchor.transform)
                anchorEntity.position = annotation.position3D
                
                let markerMesh = MeshResource.generateSphere(radius: 0.05)
                let markerMaterial = SimpleMaterial(color: .white, isMetallic: false)
                let markerEntity = ModelEntity(mesh: markerMesh, materials: [markerMaterial])
                
                anchorEntity.addChild(markerEntity)
                arView.scene.addAnchor(anchorEntity)
                
                annotationEntities[annotation.id.uuidString] = anchorEntity
            }
        }
        
        // MARK: - Developer Mode: Establish Reference Point
        
        /// Raycasts from the bounding box center to establish a world-space reference point.
        func establishDevReference(for detection: StatueDetectionResult) {
            guard let arView = arView else { return }
            
            let now = Date()
            guard now.timeIntervalSince(lastReferenceAttemptTime) > 0.5 else { return }
            lastReferenceAttemptTime = now
            
            let centerX = detection.screenRect.midX
            let centerY = detection.screenRect.midY
            let centerPoint = CGPoint(x: centerX, y: centerY)
            
            let results = arView.raycast(
                from: centerPoint,
                allowing: .estimatedPlane,
                alignment: .any
            )
            
            if let hit = results.first {
                let col = hit.worldTransform.columns.3
                let worldPos = SIMD3<Float>(col.x, col.y, col.z)
                
                Task { @MainActor in
                    self.viewModel.setDevReference(worldPos)
                }
                print("📌 Reference point established at \(worldPos)")
            } else {
                Task { @MainActor in
                    self.viewModel.devStatusMessage = "Raycast missed — move closer to the statue."
                }
            }
        }
        
        // MARK: - Developer Mode: Tap to Place Anchor
        
        /// Raycasts from a screen point and places a developer anchor for the selected annotation.
        func devPlaceAnchorAtScreenPoint(_ point: CGPoint) {
            guard let arView = arView else { return }
            
            let results = arView.raycast(
                from: point,
                allowing: .estimatedPlane,
                alignment: .any
            )
            
            if let hit = results.first {
                let col = hit.worldTransform.columns.3
                let worldPos = SIMD3<Float>(col.x, col.y, col.z)
                
                Task { @MainActor in
                    guard let label = self.viewModel.devPlacingAnnotation else { return }
                    
                    // Record offset from reference
                    self.viewModel.placeDevAnchor(label: label, worldPos: worldPos)
                    
                    // Create visual anchor in the AR scene
                    self.createDevAnchorEntity(label: label, worldPos: worldPos, in: arView)
                    
                    // Mark as anchored for the overlay system
                    self.viewModel.markPointAnchored(label)
                    
                    // Auto-advance to next unplaced annotation
                    self.advanceToNextUnplacedAnnotation()
                }
            } else {
                Task { @MainActor in
                    self.viewModel.devStatusMessage = "Raycast missed — try tapping closer to the statue surface."
                }
            }
        }
        
        /// Creates or updates a visual anchor entity for a developer-placed point.
        private func createDevAnchorEntity(label: String, worldPos: SIMD3<Float>, in arView: ARView) {
            let key = "dev_\(label)"
            
            // Remove old anchor if exists
            if let old = annotationEntities[key] {
                old.removeFromParent()
            }
            // Also remove any raycast-based anchor for the same label
            let raycastKey = "raycast_\(label)"
            if let old = annotationEntities[raycastKey] {
                old.removeFromParent()
                annotationEntities.removeValue(forKey: raycastKey)
            }
            
            let anchor = AnchorEntity(world: worldPos)
            
            // Gold sphere marker for developer anchors (slightly larger for visibility)
            let markerMesh = MeshResource.generateSphere(radius: 0.03)
            let markerMaterial = SimpleMaterial(
                color: UIColor(red: 1.0, green: 0.76, blue: 0.03, alpha: 1.0),
                isMetallic: true
            )
            let markerEntity = ModelEntity(mesh: markerMesh, materials: [markerMaterial])
            
            anchor.addChild(markerEntity)
            arView.scene.addAnchor(anchor)
            
            annotationEntities[key] = anchor
        }
        
        /// Advances to the next annotation that hasn't been placed yet.
        private func advanceToNextUnplacedAnnotation() {
            guard let statue = viewModel.primaryStatue else { return }
            let annotations = statue.annotations
            
            for annotation in annotations {
                if viewModel.devPlacedAnchors[annotation.title] == nil {
                    viewModel.devPlacingAnnotation = annotation.title
                    viewModel.devStatusMessage = "Tap on the statue where \"\(annotation.title)\" should appear."
                    return
                }
            }
            
            // All placed
            viewModel.devPlacingAnnotation = nil
            viewModel.devStatusMessage = "All anchors placed! Tap 'Save All' to persist."
        }
        
        // MARK: - Restore Dev Anchors (Normal Mode)
        
        /// Uses saved developer anchor offsets + a fresh bbox center raycast
        /// to restore annotations at their calibrated world positions.
        func restoreDevAnchors(
            for statue: Statue,
            detection: StatueDetectionResult,
            arView: ARView
        ) {
            guard !devAnchorsRestored else { return }
            
            // Raycast from bbox center to get reference
            let centerPoint = CGPoint(
                x: detection.screenRect.midX,
                y: detection.screenRect.midY
            )
            
            let results = arView.raycast(
                from: centerPoint,
                allowing: .estimatedPlane,
                alignment: .any
            )
            
            guard let hit = results.first else {
                print("📌 Dev anchor restore: bbox center raycast missed, will retry")
                return
            }
            
            let col = hit.worldTransform.columns.3
            let reference = SIMD3<Float>(col.x, col.y, col.z)
            
            // Compute world positions from saved offsets
            devAnchorsRestored = true // Mark immediately to prevent re-entry
            Task { @MainActor in
                let worldPositions = self.viewModel.computeDevAnchorWorldPositions(reference: reference)
            
                for (label, worldPos) in worldPositions {
                    self.createDevAnchorEntity(label: label, worldPos: worldPos, in: arView)
                    self.viewModel.markPointAnchored(label)
                }
            
                print("📌 Restored \(worldPositions.count) dev anchors from saved data")
            }
        }
        
        // MARK: - Raycast Anchoring (Approach 2 — fallback when no dev anchors)
        
        /// Raycasts from screen positions to place 3D anchors for annotation points.
        /// Only runs once per label per detection cycle.
        func performRaycastAnchoring(
            for statue: Statue,
            detection: StatueDetectionResult,
            arView: ARView
        ) {
            let points = statue.annotationPoints
            
            for point in points {
                guard !raycastedLabels.contains(point.label) else { continue }
                
                let screenX = detection.screenRect.origin.x + point.relativeX * detection.screenRect.width
                let screenY = detection.screenRect.origin.y + point.relativeY * detection.screenRect.height
                let screenPoint = CGPoint(x: screenX, y: screenY)
                
                raycastedLabels.insert(point.label)
                
                let results = arView.raycast(
                    from: screenPoint,
                    allowing: .estimatedPlane,
                    alignment: .any
                )
                
                if let hit = results.first {
                    let key = "raycast_\(point.label)"
                    if let oldAnchor = annotationEntities[key] {
                        oldAnchor.removeFromParent()
                    }
                    
                    let anchor = AnchorEntity(world: hit.worldTransform)
                    
                    let markerMesh = MeshResource.generateSphere(radius: 0.02)
                    let markerMaterial = SimpleMaterial(color: .white, isMetallic: false)
                    let markerEntity = ModelEntity(mesh: markerMesh, materials: [markerMaterial])
                    
                    anchor.addChild(markerEntity)
                    arView.scene.addAnchor(anchor)
                    
                    annotationEntities[key] = anchor
                    
                    Task { @MainActor in
                        self.viewModel.markPointAnchored(point.label)
                    }
                    print("🎯 Raycast hit for \(point.label) at \(hit.worldTransform.columns.3)")
                } else {
                    print("⚠️ Raycast miss for \(point.label) — keeping screen-space dot")
                    raycastedLabels.remove(point.label)
                }
            }
        }
        
        /// Removes all 3D anchors from the AR scene and resets tracking state.
        func clearAllAnchors() {
            for (_, anchorEntity) in annotationEntities {
                anchorEntity.removeFromParent()
            }
            annotationEntities.removeAll()
            raycastedLabels.removeAll()
            devAnchorsRestored = false
        }
        
        func updateAnnotations(_ annotations: [Annotation]) {
            let newIDs = Set(annotations.map(\.id))
            guard newIDs != lastAnnotationIDs else { return }
            lastAnnotationIDs = newIDs
            clearAllAnchors()
        }
        
        // MARK: - Tap Handling
        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let arView = arView else { return }
            
            let location = recognizer.location(in: arView)
            
            // Developer mode: tap to place anchor
            if viewModel.developerMode,
               viewModel.devPlacingAnnotation != nil,
               viewModel.devReferenceEstablished {
                devPlaceAnchorAtScreenPoint(location)
                return
            }
            
            // Normal mode: tap to select annotation entity
            if let entity = arView.entity(at: location) {
                for (id, anchorEntity) in annotationEntities {
                    if anchorEntity.children.contains(where: { $0 == entity }) {
                        // Check both UUID and label-based keys
                        let annotation: Annotation?
                        if id.hasPrefix("dev_") || id.hasPrefix("raycast_") {
                            let label = id.hasPrefix("dev_")
                                ? String(id.dropFirst("dev_".count))
                                : String(id.dropFirst("raycast_".count))
                            annotation = viewModel.currentAnnotations.first(where: { $0.title == label })
                        } else {
                            annotation = viewModel.currentAnnotations.first(where: { $0.id.uuidString == id })
                        }
                        
                        if let annotation {
                            Task { @MainActor in
                                NotificationCenter.default.post(
                                    name: .annotationTapped,
                                    object: annotation
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let annotationTapped = Notification.Name("annotationTapped")
}

#Preview {
    ARCameraView()
}
