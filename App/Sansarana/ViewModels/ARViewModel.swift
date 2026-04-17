//
//  ARViewModel.swift
//  Sansarana
//
//  Created by Chulan Shammi on 2026-03-18.
//

import SwiftUI
import ARKit
import CoreML
import Combine
@preconcurrency import Vision

@MainActor
class ARViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Legacy single-statue (used by reference image detection path).
    @Published var detectedStatue: Statue?
    @Published var isStatueDetected = false
    @Published var currentAnnotations: [Annotation] = []
    @Published var classificationConfidence: Float = 0.0
    
    // Object Detection (CoreML)
    @Published var detectedStatues: [StatueDetectionResult] = []
    @Published var primaryStatue: Statue?
    @Published var calibrationMode: Bool = false
    
    /// Labels of annotation points that have been upgraded to 3D anchors (Approach 2).
    @Published var anchoredPointLabels: Set<String> = []
    
    /// Screen-projected positions of 3D anchors (keyed by annotation label).
    @Published var annotationScreenPositions: [String: CGPoint] = [:]
    
    /// Screen size provided by the AR view for coordinate conversion.
    @Published var screenSize: CGSize = .zero
    
    // Bounding box stability tracking (for Approach 2 raycast trigger).
    @Published var boundingBoxStable: Bool = false
    private var stabilityFrameCount: Int = 0
    private var lastBoundingBoxCenter: CGPoint = .zero
    /// Counts consecutive detection frames with no statue found (for grace period before clearing UI).
    private var noDetectionFrameCount: Int = 0
    
    // Calibration data (Approach 3 — legacy).
    @Published var calibratedPositions: [String: [CalibratedPosition]] = [:]
    @Published var selectedCalibrationPoint: String?
    @Published var calibrationOffset: SIMD3<Float> = .zero
    
    // MARK: - Developer Mode (Persistent AR Anchor Placement)
    
    /// Whether developer mode is active (tap-to-place anchors on the live AR view).
    @Published var developerMode: Bool = false
    /// The annotation label currently selected for placement in developer mode.
    @Published var devPlacingAnnotation: String?
    /// World-space position from raycasting the bounding box center (reference point).
    @Published var devReferenceWorldPos: SIMD3<Float>?
    /// Currently placed developer anchors (label → world offset from reference).
    @Published var devPlacedAnchors: [String: SIMD3<Float>] = [:]
    /// Whether a reference point has been established for the current detection.
    @Published var devReferenceEstablished: Bool = false
    /// Status message shown in developer mode overlay.
    @Published var devStatusMessage: String = ""
    
    // MARK: - Private Properties
    private var visionModel: VNCoreMLModel?
    /// Stored as nonisolated(unsafe) so it can be read from the background detection queue.
    /// It is created once during init and never mutated afterwards.
    nonisolated(unsafe) private var detectionRequest: VNCoreMLRequest?
    private let detectionQueue = DispatchQueue(label: "com.sansarana.detection", qos: .userInitiated)
    
    init() {
        setupObjectDetection()
        loadCalibrationData()
    }
    
    // MARK: - CoreML Object Detection Setup
    private func setupObjectDetection() {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            let model = try StatueDetection(configuration: config)
            let vnModel = try VNCoreMLModel(for: model.model)
            visionModel = vnModel
            
            let request = VNCoreMLRequest(model: vnModel) { [weak self] request, error in
                guard let self else { return }
                self.handleDetection(request: request, error: error)
            }
            request.imageCropAndScaleOption = .scaleFill
            detectionRequest = request
            print("🔍 StatueDetection model loaded successfully")
        } catch {
            print("⚠️ Failed to load StatueDetection model: \(error)")
        }
    }
    
    // MARK: - Frame Processing
    
    /// Called by the ARSession delegate on every frame update.
    /// Accepts only the pixel buffer (not the full ARFrame) to avoid retaining frames.
    nonisolated func classifyPixelBuffer(_ pixelBuffer: CVPixelBuffer) {
        guard let request = detectionRequest else { return }
        
        nonisolated(unsafe) let buffer = pixelBuffer
        detectionQueue.async {
            let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .right, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("⚠️ Detection error: \(error)")
            }
        }
    }
    
    // MARK: - Detection Handler
    
    private nonisolated func handleDetection(request: VNRequest, error: Error?) {
        if let error {
            print("⚠️ Detection request error: \(error)")
            return
        }
        
        guard let results = request.results as? [VNRecognizedObjectObservation] else { return }
        
        // Filter by confidence.
        let filtered = results.filter { $0.confidence > 0.7 }
        
        Task { @MainActor [weak self] in
            guard let self else { return }
            
            let screenSize = self.screenSize
            guard screenSize.width > 0, screenSize.height > 0 else { return }
            
            var newDetections: [StatueDetectionResult] = []
            
            for observation in filtered {
                guard let topLabel = observation.labels.first else { continue }
                
                let statue: Statue
                switch topLabel.identifier.lowercased() {
                case "seated":
                    statue = .seatedBuddha
                case "standing":
                    statue = .standingBuddha
                case "reclining":
                    statue = .recliningBuddha
                default:
                    continue
                }
                
                let bb = observation.boundingBox
                // Vision bbox: origin bottom-left, normalised 0-1.
                // Convert to screen coords: origin top-left, pixels.
                let screenRect = CGRect(
                    x: bb.origin.x * screenSize.width,
                    y: (1 - bb.origin.y - bb.height) * screenSize.height,
                    width: bb.width * screenSize.width,
                    height: bb.height * screenSize.height
                )
                
                let result = StatueDetectionResult(
                    statue: statue,
                    boundingBox: bb,
                    confidence: observation.confidence,
                    screenRect: screenRect
                )
                newDetections.append(result)
                print("🔍 Detected \(statue.title) — confidence: \(String(format: "%.1f%%", observation.confidence * 100))")
            }
            
            self.detectedStatues = newDetections
            
            // Update primary statue (highest confidence).
            if let best = newDetections.max(by: { $0.confidence < $1.confidence }) {
                self.noDetectionFrameCount = 0
                
                if self.primaryStatue != best.statue {
                    self.resetDetectionState()
                    self.primaryStatue = best.statue
                    // Also update legacy properties for backward compat.
                    self.detectedStatue = best.statue
                    self.isStatueDetected = true
                    self.loadAnnotations(for: best.statue)
                }
                self.classificationConfidence = best.confidence
                
                // Track bounding box stability for Approach 2.
                let center = CGPoint(
                    x: best.screenRect.midX,
                    y: best.screenRect.midY
                )
                let threshold = screenSize.width * 0.1
                let distance = hypot(center.x - self.lastBoundingBoxCenter.x,
                                     center.y - self.lastBoundingBoxCenter.y)
                if distance < threshold {
                    self.stabilityFrameCount += 1
                } else {
                    self.stabilityFrameCount = 0
                }
                self.lastBoundingBoxCenter = center
                // Stable after ~3 detections at 0.5s = 1.5s.
                self.boundingBoxStable = self.stabilityFrameCount >= 3
            } else {
                // No statue detected — clear state after grace period to avoid flicker.
                self.noDetectionFrameCount += 1
                if self.noDetectionFrameCount >= 4 { // 4 frames x 0.5s = 2s grace
                    self.primaryStatue = nil
                    self.detectedStatue = nil
                    self.isStatueDetected = false
                    self.currentAnnotations = []
                    self.classificationConfidence = 0.0
                    self.resetDetectionState()
                    self.noDetectionFrameCount = 0
                }
            }
        }
    }
    
    // MARK: - Primary Statue Selection
    
    func selectPrimaryStatue(_ statue: Statue) {
        resetDetectionState()
        primaryStatue = statue
        detectedStatue = statue
        isStatueDetected = true
        loadAnnotations(for: statue)
    }
    
    // MARK: - Statue Detection (Reference Image path — kept for backward compat)
    func handleStatueDetection(_ statueName: String, anchor: ARImageAnchor) {
        updateDetectedStatue(from: statueName)
        isStatueDetected = true
    }
    
    private func updateDetectedStatue(from identifier: String) {
        let statue: Statue
        
        switch identifier.lowercased() {
        case "seated", "seatedbuddha", "vijjadhara":
            statue = .seatedBuddha
        case "standing", "standingbuddha":
            statue = .standingBuddha
        case "reclining", "recliningbuddha", "parinirvana":
            statue = .recliningBuddha
        default:
            return
        }
        
        if detectedStatue != statue {
            detectedStatue = statue
            primaryStatue = statue
            loadAnnotations(for: statue)
        }
    }
    
    // MARK: - Annotation Loading
    private func loadAnnotations(for statue: Statue) {
        currentAnnotations = statue.annotations
        loadDevAnchors(for: statue)
    }
    
    // MARK: - Detection State Reset
    
    /// Resets all detection tracking state. Called when the primary statue changes.
    func resetDetectionState() {
        anchoredPointLabels.removeAll()
        annotationScreenPositions.removeAll()
        boundingBoxStable = false
        stabilityFrameCount = 0
        lastBoundingBoxCenter = .zero
    }
    
    // MARK: - Anchored Points (Approach 2)
    
    func markPointAnchored(_ label: String) {
        anchoredPointLabels.insert(label)
        print("📍 Placed 3D anchor for: \(label)")
    }
    
    func updateAnnotationScreenPosition(_ label: String, position: CGPoint) {
        annotationScreenPositions[label] = position
    }
    
    func removeAnnotationScreenPosition(_ label: String) {
        annotationScreenPositions.removeValue(forKey: label)
    }
    
    // MARK: - Calibration (Approach 3)
    
    func hasCalibrationData(for statue: Statue) -> Bool {
        guard let positions = calibratedPositions[statue.rawValue] else { return false }
        return !positions.isEmpty
    }
    
    func getCalibrationData(for statue: Statue) -> [CalibratedPosition] {
        calibratedPositions[statue.rawValue] ?? []
    }
    
    func saveCalibrationData(for statue: Statue, positions: [CalibratedPosition]) {
        calibratedPositions[statue.rawValue] = positions
        
        // Persist to UserDefaults.
        if let data = try? JSONEncoder().encode(calibratedPositions) {
            UserDefaults.standard.set(data, forKey: "calibratedPositions")
            print("⚙️ Calibration data saved for \(statue.title)")
        }
    }
    
    private func loadCalibrationData() {
        guard let data = UserDefaults.standard.data(forKey: "calibratedPositions"),
              let decoded = try? JSONDecoder().decode([String: [CalibratedPosition]].self, from: data) else {
            return
        }
        calibratedPositions = decoded
        print("⚙️ Calibration data loaded: \(decoded.keys.joined(separator: ", "))")
    }
    
    func copyCalibrationToClipboard(for statue: Statue) {
        let positions = getCalibrationData(for: statue)
        guard !positions.isEmpty else { return }
        
        var output = "// \(statue.title) calibrated positions\n"
        for pos in positions {
            output += "(\"\(pos.label)\", SIMD3<Float>(\(pos.offset.x), \(pos.offset.y), \(pos.offset.z))),\n"
        }
        UIPasteboard.general.string = output
        print("⚙️ Calibration positions copied to clipboard")
        print(output)
    }
    
    // MARK: - Developer Mode Anchor Placement
    
    /// Loads any previously saved developer anchors for the given statue.
    func loadDevAnchors(for statue: Statue) {
        if let saved = DevAnchorStore.load(for: statue) {
            devPlacedAnchors = Dictionary(uniqueKeysWithValues: saved.map { ($0.label, $0.offset) })
            print("📌 Loaded \(saved.count) dev anchors for \(statue.title)")
        } else {
            devPlacedAnchors = [:]
        }
    }
    
    /// Whether there are saved developer anchors for a statue.
    func hasDevAnchors(for statue: Statue) -> Bool {
        DevAnchorStore.hasData(for: statue)
    }
    
    /// Sets the reference world position (from bounding box center raycast).
    func setDevReference(_ worldPos: SIMD3<Float>) {
        devReferenceWorldPos = worldPos
        devReferenceEstablished = true
        devStatusMessage = "Reference set. Select an annotation to place."
        print("📌 Dev reference point: \(worldPos)")
    }
    
    /// Records a placed anchor as an offset from the reference point.
    func placeDevAnchor(label: String, worldPos: SIMD3<Float>) {
        guard let reference = devReferenceWorldPos else {
            devStatusMessage = "No reference point. Point camera at statue."
            return
        }
        let offset = worldPos - reference
        devPlacedAnchors[label] = offset
        devStatusMessage = "\(label) placed. Offset: (\(String(format: "%.3f", offset.x)), \(String(format: "%.3f", offset.y)), \(String(format: "%.3f", offset.z)))"
        print("📌 Placed \(label) — offset: \(offset)")
    }
    
    /// Saves all currently placed developer anchors to persistent storage.
    func saveDevAnchors() {
        guard let statue = primaryStatue else { return }
        let anchors = devPlacedAnchors.map { DevAnchorData(label: $0.key, offset: $0.value) }
        DevAnchorStore.save(anchors, for: statue)
        devStatusMessage = "All anchors saved! (\(anchors.count) points)"
    }
    
    /// Clears all developer anchors for the current statue.
    func clearDevAnchors() {
        guard let statue = primaryStatue else { return }
        DevAnchorStore.clear(for: statue)
        devPlacedAnchors = [:]
        devReferenceWorldPos = nil
        devReferenceEstablished = false
        devStatusMessage = "Anchors cleared."
    }
    
    /// Computes world positions for all saved anchors given a new reference point.
    /// Used during normal mode to restore anchor positions.
    func computeDevAnchorWorldPositions(reference: SIMD3<Float>) -> [String: SIMD3<Float>] {
        var result: [String: SIMD3<Float>] = [:]
        for (label, offset) in devPlacedAnchors {
            result[label] = reference + offset
        }
        return result
    }
    
    /// Resets developer mode state (called when statue changes or mode exits).
    func resetDeveloperMode() {
        devPlacingAnnotation = nil
        devReferenceWorldPos = nil
        devReferenceEstablished = false
        devStatusMessage = ""
    }
}

