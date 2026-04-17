//
//  DetailView.swift
//  Sansarana
//
//  Created by Chulan Shammi on 2026-03-18.
//

import SwiftUI
import MetalSplatter
import Metal
import SplatIO
import simd

// MARK: - Anchor Position Persistence

struct AnchorPositionStore {
    private static func dotKey(for statue: Statue) -> String {
        "anchorPositions_\(statue.rawValue)"
    }
    
    private static func cardKey(for statue: Statue) -> String {
        "anchorCardPositions_\(statue.rawValue)"
    }
    
    // MARK: - Dot positions (3D)
    
    static func loadDots(for statue: Statue) -> [String: SIMD3<Float>]? {
        guard let data = UserDefaults.standard.data(forKey: dotKey(for: statue)),
              let entries = try? JSONDecoder().decode([AnchorEntry].self, from: data) else {
            return nil
        }
        var result: [String: SIMD3<Float>] = [:]
        for entry in entries {
            result[entry.name] = SIMD3<Float>(entry.x, entry.y, entry.z)
        }
        return result
    }
    
    static func saveDots(_ positions: [String: SIMD3<Float>], for statue: Statue) {
        let entries = positions.map { AnchorEntry(name: $0.key, x: $0.value.x, y: $0.value.y, z: $0.value.z) }
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: dotKey(for: statue))
            print("Saved anchor dot positions for \(statue.title)")
        }
    }
    
    // MARK: - Card positions (2D screen offsets from rest position)
    
    static func loadCards(for statue: Statue) -> [String: CGSize]? {
        guard let data = UserDefaults.standard.data(forKey: cardKey(for: statue)),
              let entries = try? JSONDecoder().decode([CardEntry].self, from: data) else {
            return nil
        }
        var result: [String: CGSize] = [:]
        for entry in entries {
            result[entry.name] = CGSize(width: entry.dx, height: entry.dy)
        }
        return result
    }
    
    static func saveCards(_ positions: [String: CGSize], for statue: Statue) {
        let entries = positions.map { CardEntry(name: $0.key, dx: $0.value.width, dy: $0.value.height) }
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: cardKey(for: statue))
            print("Saved anchor card positions for \(statue.title)")
        }
    }
    
    // MARK: - Backwards-compatible load (returns dot positions)
    
    static func load(for statue: Statue) -> [String: SIMD3<Float>]? {
        loadDots(for: statue)
    }
    
    // MARK: - Clear all
    
    static func clear(for statue: Statue) {
        UserDefaults.standard.removeObject(forKey: dotKey(for: statue))
        UserDefaults.standard.removeObject(forKey: cardKey(for: statue))
    }
    
    private struct AnchorEntry: Codable {
        let name: String
        let x: Float
        let y: Float
        let z: Float
    }
    
    private struct CardEntry: Codable {
        let name: String
        let dx: CGFloat
        let dy: CGFloat
    }
}

// MARK: - Saved Viewer Defaults

struct SplatViewerSavedDefaults: Codable {
    var cameraX: Float
    var cameraY: Float
    var cameraZ: Float
    var rotationX: Float
    var rotationY: Float
    var rotationZ: Float
    var positionX: Float
    var positionY: Float
    var positionZ: Float
    var scale: Float
    var gestureRotationX: Float
    var gestureRotationY: Float
    var zoomScale: Float
    var cameraOrbitX: Float = 0.0
    var cameraOrbitY: Float = 0.0
    
    static func userDefaultsKey(for statue: Statue) -> String {
        "splatViewerDefaults_\(statue.rawValue)"
    }
    
    static func load(for statue: Statue) -> SplatViewerSavedDefaults? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey(for: statue)),
              let defaults = try? JSONDecoder().decode(SplatViewerSavedDefaults.self, from: data) else {
            return nil
        }
        return defaults
    }
    
    func save(for statue: Statue) {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.userDefaultsKey(for: statue))
            print("Saved splat viewer defaults for \(statue.title)")
        }
    }
}

struct DetailView: View {
    let statue: Statue
    let annotation: Annotation
    
    @Environment(\.dismiss) private var dismiss
    @State private var renderer: SplatRenderer?
    @State private var displayedAnnotation: Annotation?
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Top 60% - 3D Gaussian Splat Viewer
                    SplatViewerSection(
                        statue: statue,
                        annotation: annotation,
                        renderer: $renderer,
                        highlightedAnnotationTitle: displayedAnnotation?.title,
                        onAnnotationTapped: { tapped in
                            withAnimation(.easeInOut(duration: 0.3)) {
                                displayedAnnotation = tapped
                            }
                        },
                        height: geometry.size.height * 0.6
                    )
                    
                    // Bottom 40% - Annotation Info (updates when cards are tapped)
                    AnnotationInfoSection(annotation: displayedAnnotation ?? annotation)
                        .frame(height: geometry.size.height * 0.4)
                        .id(displayedAnnotation?.title ?? annotation.title)
                        .transition(.opacity)
                }
            }
            .navigationTitle(statue.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .ignoresSafeArea(.container, edges: .bottom)
        }
        .onAppear {
            displayedAnnotation = annotation
        }
    }
}

struct SplatViewerSection: View {
    let statue: Statue
    let annotation: Annotation
    @Binding var renderer: SplatRenderer?
    /// The title of the currently highlighted annotation
    var highlightedAnnotationTitle: String? = nil
    /// Callback when a card is tapped in read-only mode
    var onAnnotationTapped: ((Annotation) -> Void)? = nil
    let height: CGFloat
    
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var showControls = false
    
    // Camera controls
    @State private var cameraX: Float
    @State private var cameraY: Float
    @State private var cameraZ: Float
    
    // User-interactive rotation controls (additive on top of base rotation)
    @State private var rotationX: Float
    @State private var rotationY: Float
    @State private var rotationZ: Float
    
    // Model position offset
    @State private var positionX: Float
    @State private var positionY: Float
    @State private var positionZ: Float
    
    // Scale
    @State private var scale: Float
    
    // Gesture-driven state (synced from Coordinator)
    @State private var gestureRotationX: Float
    @State private var gestureRotationY: Float
    @State private var zoomScale: Float
    @State private var cameraOrbitX: Float
    @State private var cameraOrbitY: Float
    
    // Anchor placement (developer mode)
    @State private var editAnchors = false
    @State private var editedPositions: [String: SIMD3<Float>] = [:]
    @State private var mvpMatrix: simd_float4x4 = matrix_identity_float4x4
    @State private var viewportSize: CGSize = CGSize(width: 1, height: 1)
    @State private var hasSavedAnchors: Bool = false
    @State private var cardPositions: [String: CGSize] = [:]
    
    init(
        statue: Statue,
        annotation: Annotation,
        renderer: Binding<SplatRenderer?>,
        highlightedAnnotationTitle: String? = nil,
        onAnnotationTapped: ((Annotation) -> Void)? = nil,
        height: CGFloat
    ) {
        self.statue = statue
        self.annotation = annotation
        self._renderer = renderer
        self.highlightedAnnotationTitle = highlightedAnnotationTitle
        self.onAnnotationTapped = onAnnotationTapped
        self.height = height
        
        // Check for saved defaults first, fall back to hardcoded
        if let saved = SplatViewerSavedDefaults.load(for: statue) {
            _cameraX = State(initialValue: saved.cameraX)
            _cameraY = State(initialValue: saved.cameraY)
            _cameraZ = State(initialValue: saved.cameraZ)
            _rotationX = State(initialValue: saved.rotationX)
            _rotationY = State(initialValue: saved.rotationY)
            _rotationZ = State(initialValue: saved.rotationZ)
            _positionX = State(initialValue: saved.positionX)
            _positionY = State(initialValue: saved.positionY)
            _positionZ = State(initialValue: saved.positionZ)
            _scale = State(initialValue: saved.scale)
            _gestureRotationX = State(initialValue: saved.gestureRotationX)
            _gestureRotationY = State(initialValue: saved.gestureRotationY)
            _zoomScale = State(initialValue: saved.zoomScale)
            _cameraOrbitX = State(initialValue: saved.cameraOrbitX)
            _cameraOrbitY = State(initialValue: saved.cameraOrbitY)
        } else {
            let cam = statue.defaultCameraPosition
            _cameraX = State(initialValue: cam.x)
            _cameraY = State(initialValue: cam.y)
            _cameraZ = State(initialValue: cam.z)
            let rot = statue.defaultModelRotation
            _rotationX = State(initialValue: rot.x)
            _rotationY = State(initialValue: rot.y)
            _rotationZ = State(initialValue: rot.z)
            let pos = statue.defaultModelPosition
            _positionX = State(initialValue: pos.x)
            _positionY = State(initialValue: pos.y)
            _positionZ = State(initialValue: pos.z)
            _scale = State(initialValue: statue.defaultScale)
            let gestureRot = statue.defaultGestureRotation
            _gestureRotationX = State(initialValue: gestureRot.x)
            _gestureRotationY = State(initialValue: gestureRot.y)
            _zoomScale = State(initialValue: statue.defaultZoomScale)
            let orbit = statue.defaultCameraOrbit
            _cameraOrbitX = State(initialValue: orbit.x)
            _cameraOrbitY = State(initialValue: orbit.y)
        }
        
        // Load saved anchor positions or use defaults from annotations
        if let savedAnchors = AnchorPositionStore.loadDots(for: statue) {
            _editedPositions = State(initialValue: savedAnchors)
            _hasSavedAnchors = State(initialValue: true)
        } else {
            var positions: [String: SIMD3<Float>] = [:]
            for ann in statue.annotations {
                positions[ann.title] = ann.position3D
            }
            _editedPositions = State(initialValue: positions)
            _hasSavedAnchors = State(initialValue: false)
        }
        
        // Load saved card positions
        if let savedCards = AnchorPositionStore.loadCards(for: statue) {
            _cardPositions = State(initialValue: savedCards)
        }
    }
    
    var body: some View {
        ZStack {
            Color.black
            
            if isLoading {
                ProgressView("Loading 3D model...")
                    .tint(.white)
                    .foregroundStyle(.white)
            } else if let error = loadError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.yellow)
                    
                    Text("Failed to load model")
                        .font(.headline)
                        .foregroundStyle(.white)
                    
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                SplatView(
                    renderer: $renderer,
                    cameraPosition: SIMD3<Float>(cameraX, cameraY, cameraZ),
                    centerOffset: statue.defaultCenterOffset,
                    baseRotation: statue.defaultBaseRotation,
                    modelRotation: SIMD3<Float>(rotationX, rotationY, rotationZ),
                    modelPosition: SIMD3<Float>(positionX, positionY, positionZ),
                    modelScale: scale,
                    gestureRotationX: $gestureRotationX,
                    gestureRotationY: $gestureRotationY,
                    zoomScale: $zoomScale,
                    cameraOrbitX: $cameraOrbitX,
                    cameraOrbitY: $cameraOrbitY,
                    onMVPMatrix: { matrix, viewport in
                        mvpMatrix = matrix
                        viewportSize = viewport
                    }
                )
                
                // Annotation overlay — always visible; draggable only in developer edit mode
                AnchorPlacementOverlay(
                    annotations: statue.annotations,
                    editedPositions: $editedPositions,
                    cardPositions: $cardPositions,
                    mvpMatrix: mvpMatrix,
                    viewportSize: viewportSize,
                    hasSavedAnchors: hasSavedAnchors,
                    isEditable: editAnchors,
                    highlightedAnnotationTitle: editAnchors ? nil : highlightedAnnotationTitle,
                    onAnnotationTapped: editAnchors ? nil : onAnnotationTapped
                )
            }
            
            // Configuration controls overlay (developer-only, triggered by triple-tap)
            if showControls {
                VStack {
                    Spacer()
                    ModelConfigControls(
                        statue: statue,
                        cameraX: $cameraX,
                        cameraY: $cameraY,
                        cameraZ: $cameraZ,
                        rotationX: $rotationX,
                        rotationY: $rotationY,
                        rotationZ: $rotationZ,
                        positionX: $positionX,
                        positionY: $positionY,
                        positionZ: $positionZ,
                        scale: $scale,
                        gestureRotationX: $gestureRotationX,
                        gestureRotationY: $gestureRotationY,
                        zoomScale: $zoomScale,
                        cameraOrbitX: $cameraOrbitX,
                        cameraOrbitY: $cameraOrbitY,
                        isShowing: $showControls,
                        editAnchors: $editAnchors,
                        editedPositions: $editedPositions,
                        cardPositions: $cardPositions,
                        hasSavedAnchors: $hasSavedAnchors
                    )
                }
            }
        }
        .frame(height: height)
        .contentShape(Rectangle())
        .onTapGesture(count: 3) {
            showControls.toggle()
        }
        .task {
            await loadSplatModel()
        }
    }
    
    private func loadSplatModel() async {
        print("🟢 Loading 3D model: \(statue.splatFileName)")
        
        // Find the PLY file
        let fileName = statue.splatFileName.replacingOccurrences(of: ".ply", with: "")
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "ply") else {
            loadError = "Model file not found: \(statue.splatFileName)"
            isLoading = false
            return
        }
        
        // Create Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            loadError = "Metal not supported"
            isLoading = false
            return
        }
        
        do {
            // Create renderer
            let newRenderer = try SplatRenderer(
                device: device,
                colorFormat: .bgra8Unorm,
                depthFormat: .depth32Float,
                sampleCount: 1,
                maxViewCount: 1,
                maxSimultaneousRenders: 3
            )
            
            // Load PLY via SplatIO, create a MetalBuffer chunk, and add to renderer.
            let points = try await AutodetectSceneReader(url).readAll()
            let buffer = try MetalBuffer<EncodedSplatPoint>(device: device)
            try buffer.ensureCapacity(points.count)
            buffer.append(points.map { EncodedSplatPoint($0) })
            let chunk = SplatChunk(splats: buffer)
            await newRenderer.addChunk(chunk)
            
            renderer = newRenderer
            isLoading = false
            print("✅ Model loaded successfully")
            
        } catch {
            loadError = "Failed to load model: \(error.localizedDescription)"
            isLoading = false
            print("❌ Error: \(error)")
        }
    }
}

struct AnnotationInfoSection: View {
    let annotation: Annotation
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("About")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(annotation.content.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                
                // Facts
                if !annotation.content.facts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Key Facts")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        ForEach(annotation.content.facts.indices, id: \.self) { index in
                            HStack(alignment: .top, spacing: 12) {
                                Circle()
                                    .fill(.blue)
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 6)
                                
                                Text(annotation.content.facts[index])
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                // Images (if any)
                if !annotation.content.images.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Gallery")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(annotation.content.images, id: \.self) { imageName in
                                    if let uiImage = UIImage(named: imageName) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 200, height: 150)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color(.systemBackground))
    }
}

struct ModelConfigControls: View {
    let statue: Statue
    @Binding var cameraX: Float
    @Binding var cameraY: Float
    @Binding var cameraZ: Float
    @Binding var rotationX: Float
    @Binding var rotationY: Float
    @Binding var rotationZ: Float
    @Binding var positionX: Float
    @Binding var positionY: Float
    @Binding var positionZ: Float
    @Binding var scale: Float
    @Binding var gestureRotationX: Float
    @Binding var gestureRotationY: Float
    @Binding var zoomScale: Float
    @Binding var cameraOrbitX: Float
    @Binding var cameraOrbitY: Float
    @Binding var isShowing: Bool
    @Binding var editAnchors: Bool
    @Binding var editedPositions: [String: SIMD3<Float>]
    @Binding var cardPositions: [String: CGSize]
    @Binding var hasSavedAnchors: Bool
    
    @State private var saveConfirmation = false
    @State private var anchorSaveConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("3D Model Configuration")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Button("Copy Values") {
                        copyValuesToClipboard()
                    }
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                }
                
                // Camera Position
                GroupBox("Camera Position") {
                    VStack(spacing: 12) {
                        SliderControl(title: "X", value: $cameraX, range: -5...5)
                        SliderControl(title: "Y", value: $cameraY, range: -5...5)
                        SliderControl(title: "Z", value: $cameraZ, range: -10...10)
                    }
                }
                .backgroundStyle(.ultraThinMaterial)
                
                // Model Rotation (in degrees)
                GroupBox("Model Rotation (degrees)") {
                    VStack(spacing: 12) {
                        SliderControl(title: "X", value: Binding(
                            get: { rotationX * 180 / .pi },
                            set: { rotationX = $0 * .pi / 180 }
                        ), range: -180...180)
                        SliderControl(title: "Y", value: Binding(
                            get: { rotationY * 180 / .pi },
                            set: { rotationY = $0 * .pi / 180 }
                        ), range: -180...180)
                        SliderControl(title: "Z", value: Binding(
                            get: { rotationZ * 180 / .pi },
                            set: { rotationZ = $0 * .pi / 180 }
                        ), range: -180...180)
                    }
                }
                .backgroundStyle(.ultraThinMaterial)
                
                // Model Position Offset
                GroupBox("Model Position") {
                    VStack(spacing: 12) {
                        SliderControl(title: "X", value: $positionX, range: -2...2)
                        SliderControl(title: "Y", value: $positionY, range: -2...2)
                        SliderControl(title: "Z", value: $positionZ, range: -2...2)
                    }
                }
                .backgroundStyle(.ultraThinMaterial)
                
                // Scale
                GroupBox("Model Scale") {
                    SliderControl(title: "Scale", value: $scale, range: 0.1...5.0)
                }
                .backgroundStyle(.ultraThinMaterial)
                
                // Gesture state (read-only display)
                GroupBox("Gesture State") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Drag X:")
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.1f°", gestureRotationX * 180 / .pi))
                                .font(.caption.monospacedDigit())
                        }
                        HStack {
                            Text("Drag Y:")
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.1f°", gestureRotationY * 180 / .pi))
                                .font(.caption.monospacedDigit())
                        }
                        HStack {
                            Text("Zoom:")
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.3fx", zoomScale))
                                .font(.caption.monospacedDigit())
                        }
                        HStack {
                            Text("Orbit X:")
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.1f°", cameraOrbitX * 180 / .pi))
                                .font(.caption.monospacedDigit())
                        }
                        HStack {
                            Text("Orbit Y:")
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.1f°", cameraOrbitY * 180 / .pi))
                                .font(.caption.monospacedDigit())
                        }
                    }
                }
                .backgroundStyle(.ultraThinMaterial)
                
                // Save / Reset buttons
                HStack(spacing: 12) {
                    Button(action: saveAsDefault) {
                        Label(saveConfirmation ? "Saved!" : "Save as Default", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    
                    Button(action: resetToSaved) {
                        Label("Reset to Saved", systemImage: "arrow.uturn.backward")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                }
                
                Button(action: resetToHardcodedDefaults) {
                    Label("Reset to Factory", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                
                Divider()
                
                // Anchor Placement section
                GroupBox("Anchor Placement") {
                    VStack(spacing: 12) {
                        Toggle("Edit Anchors", isOn: $editAnchors)
                            .tint(Color.saffronGold)
                        
                        if editAnchors {
                            // Show current anchor positions
                            ForEach(statue.annotations) { ann in
                                if let pos = editedPositions[ann.title] {
                                    HStack {
                                        Text(ann.title)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(String(format: "(%.3f, %.3f, %.3f)", pos.x, pos.y, pos.z))
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundStyle(.primary)
                                    }
                                }
                            }
                        }
                        
                        HStack(spacing: 12) {
                            Button(action: saveAnchors) {
                                Label(anchorSaveConfirmation ? "Saved!" : "Save Anchors", systemImage: "mappin.and.ellipse")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            
                            Button(action: resetAnchors) {
                                Label("Reset Anchors", systemImage: "arrow.uturn.backward")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        }
                    }
                }
                .backgroundStyle(.ultraThinMaterial)
            }
            .padding()
        }
        .frame(maxHeight: 450)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding()
    }
    
    private func saveAsDefault() {
        let defaults = SplatViewerSavedDefaults(
            cameraX: cameraX, cameraY: cameraY, cameraZ: cameraZ,
            rotationX: rotationX, rotationY: rotationY, rotationZ: rotationZ,
            positionX: positionX, positionY: positionY, positionZ: positionZ,
            scale: scale,
            gestureRotationX: gestureRotationX,
            gestureRotationY: gestureRotationY,
            zoomScale: zoomScale,
            cameraOrbitX: cameraOrbitX,
            cameraOrbitY: cameraOrbitY
        )
        defaults.save(for: statue)
        
        // Copy to clipboard as Swift code
        let code = """
        // \(statue.title) — saved splat viewer defaults
        // Camera: (\(cameraX), \(cameraY), \(cameraZ))
        // Slider Rotation (rad): (\(rotationX), \(rotationY), \(rotationZ))
        // Gesture Rotation (deg): X=\(String(format: "%.1f", gestureRotationX * 180 / .pi)), Y=\(String(format: "%.1f", gestureRotationY * 180 / .pi))
        // Zoom: \(String(format: "%.3f", zoomScale))
        // Camera Orbit (deg): X=\(String(format: "%.1f", cameraOrbitX * 180 / .pi)), Y=\(String(format: "%.1f", cameraOrbitY * 180 / .pi))
        // Position: (\(positionX), \(positionY), \(positionZ))
        // Scale: \(scale)
        """
        UIPasteboard.general.string = code
        
        saveConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            saveConfirmation = false
        }
    }
    
    private func resetToSaved() {
        if let saved = SplatViewerSavedDefaults.load(for: statue) {
            cameraX = saved.cameraX
            cameraY = saved.cameraY
            cameraZ = saved.cameraZ
            rotationX = saved.rotationX
            rotationY = saved.rotationY
            rotationZ = saved.rotationZ
            positionX = saved.positionX
            positionY = saved.positionY
            positionZ = saved.positionZ
            scale = saved.scale
            gestureRotationX = saved.gestureRotationX
            gestureRotationY = saved.gestureRotationY
            zoomScale = saved.zoomScale
            cameraOrbitX = saved.cameraOrbitX
            cameraOrbitY = saved.cameraOrbitY
        }
    }
    
    private func resetToHardcodedDefaults() {
        let cam = statue.defaultCameraPosition
        cameraX = cam.x
        cameraY = cam.y
        cameraZ = cam.z
        let rot = statue.defaultModelRotation
        rotationX = rot.x
        rotationY = rot.y
        rotationZ = rot.z
        let pos = statue.defaultModelPosition
        positionX = pos.x
        positionY = pos.y
        positionZ = pos.z
        scale = statue.defaultScale
        let gestureRot = statue.defaultGestureRotation
        gestureRotationX = gestureRot.x
        gestureRotationY = gestureRot.y
        zoomScale = statue.defaultZoomScale
        let orbit = statue.defaultCameraOrbit
        cameraOrbitX = orbit.x
        cameraOrbitY = orbit.y
    }
    
    private func saveAnchors() {
        AnchorPositionStore.saveDots(editedPositions, for: statue)
        AnchorPositionStore.saveCards(cardPositions, for: statue)
        hasSavedAnchors = true
        anchorSaveConfirmation = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            anchorSaveConfirmation = false
        }
    }
    
    private func resetAnchors() {
        AnchorPositionStore.clear(for: statue)
        hasSavedAnchors = false
        var positions: [String: SIMD3<Float>] = [:]
        for ann in statue.annotations {
            positions[ann.title] = ann.position3D
        }
        editedPositions = positions
        cardPositions = [:]
    }
    
    private func copyValuesToClipboard() {
        let values = """
        Camera: (\(cameraX), \(cameraY), \(cameraZ))
        Rotation: (\(rotationX), \(rotationY), \(rotationZ))
        Gesture: X=\(String(format: "%.1f°", gestureRotationX * 180 / .pi)), Y=\(String(format: "%.1f°", gestureRotationY * 180 / .pi))
        Zoom: \(String(format: "%.3f", zoomScale))
        Orbit: X=\(String(format: "%.1f°", cameraOrbitX * 180 / .pi)), Y=\(String(format: "%.1f°", cameraOrbitY * 180 / .pi))
        Position: (\(positionX), \(positionY), \(positionZ))
        Scale: \(scale)
        """
        UIPasteboard.general.string = values
    }
}

struct SliderControl: View {
    let title: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.2f", value))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.primary)
            }
            Slider(value: $value, in: range)
                .tint(.blue)
        }
    }
}

#Preview {
    DetailView(
        statue: .seatedBuddha,
        annotation: Statue.seatedBuddha.annotations[0]
    )
}
