//
//  StatueDetectionModels.swift
//  Sansarana
//
//  Data models for CoreML object detection results and annotation positioning.
//

import SwiftUI

// MARK: - Detection Result

/// Represents a single object detection from the CoreML model.
struct StatueDetectionResult: Identifiable {
    /// Stable ID based on the statue type so SwiftUI doesn't churn on every detection cycle.
    var id: String { statue.rawValue }
    let statue: Statue
    /// Normalised bounding box from Vision (origin at bottom-left, 0-1).
    let boundingBox: CGRect
    let confidence: Float
    /// Screen-space bounding box (origin at top-left, pixels).
    var screenRect: CGRect
}

// MARK: - Annotation Points (Approach 1)

/// A point defined relative to a bounding box (0.0–1.0 within the box).
struct AnnotationPoint: Identifiable {
    let id = UUID()
    let label: String
    let relativeX: CGFloat
    let relativeY: CGFloat
}

extension Statue {
    /// Relative annotation positions within the detected bounding box.
    var annotationPoints: [AnnotationPoint] {
        switch self {
        case .seatedBuddha:
            return [
                AnnotationPoint(label: "Ushnisha (crown)", relativeX: 0.5, relativeY: 0.08),
                AnnotationPoint(label: "Serene expression", relativeX: 0.5, relativeY: 0.18),
                AnnotationPoint(label: "Dhyana mudra (hands)", relativeX: 0.5, relativeY: 0.65),
                AnnotationPoint(label: "Lotus throne", relativeX: 0.5, relativeY: 0.92),
            ]
        case .standingBuddha:
            return [
                AnnotationPoint(label: "Head & face", relativeX: 0.5, relativeY: 0.08),
                AnnotationPoint(label: "Abhaya mudra (right hand)", relativeX: 0.65, relativeY: 0.4),
                AnnotationPoint(label: "Robe detail", relativeX: 0.4, relativeY: 0.6),
                AnnotationPoint(label: "Feet & base", relativeX: 0.5, relativeY: 0.95),
            ]
        case .recliningBuddha:
            return [
                AnnotationPoint(label: "Head resting on pillow", relativeX: 0.85, relativeY: 0.3),
                AnnotationPoint(label: "Serene expression", relativeX: 0.88, relativeY: 0.2),
                AnnotationPoint(label: "Robe folds", relativeX: 0.5, relativeY: 0.6),
                AnnotationPoint(label: "Feet alignment", relativeX: 0.1, relativeY: 0.7),
            ]
        }
    }
    
    /// Convert relative annotation points to screen coordinates for a given bounding box.
    func screenPositions(boundingBox: CGRect, screenSize: CGSize) -> [(String, CGPoint)] {
        annotationPoints.map { point in
            let x = boundingBox.origin.x + point.relativeX * boundingBox.width
            let y = boundingBox.origin.y + point.relativeY * boundingBox.height
            return (point.label, CGPoint(x: x, y: y))
        }
    }
}

// MARK: - Calibration Data

/// Persisted calibration offset for a single annotation point.
struct CalibratedPosition: Codable {
    let label: String
    let offset: SIMD3<Float>
    
    enum CodingKeys: String, CodingKey {
        case label, x, y, z
    }
    
    init(label: String, offset: SIMD3<Float>) {
        self.label = label
        self.offset = offset
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        label = try container.decode(String.self, forKey: .label)
        let x = try container.decode(Float.self, forKey: .x)
        let y = try container.decode(Float.self, forKey: .y)
        let z = try container.decode(Float.self, forKey: .z)
        offset = SIMD3<Float>(x, y, z)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(label, forKey: .label)
        try container.encode(offset.x, forKey: .x)
        try container.encode(offset.y, forKey: .y)
        try container.encode(offset.z, forKey: .z)
    }
}

// MARK: - Developer Mode Anchor Data

/// Persisted anchor position for a single annotation, stored as an offset
/// relative to the bounding box center raycast hit point.
/// This makes anchors independent of AR session — they only depend on
/// the statue being re-detected in the same physical location.
struct DevAnchorData: Codable {
    let label: String
    /// 3D offset in world-space meters from the bbox center raycast hit.
    let offsetX: Float
    let offsetY: Float
    let offsetZ: Float
    
    var offset: SIMD3<Float> {
        SIMD3<Float>(offsetX, offsetY, offsetZ)
    }
    
    init(label: String, offset: SIMD3<Float>) {
        self.label = label
        self.offsetX = offset.x
        self.offsetY = offset.y
        self.offsetZ = offset.z
    }
}

/// Persistence layer for developer-placed AR anchor offsets.
struct DevAnchorStore {
    private static func key(for statue: Statue) -> String {
        "devAnchors_\(statue.rawValue)"
    }
    
    static func save(_ anchors: [DevAnchorData], for statue: Statue) {
        if let data = try? JSONEncoder().encode(anchors) {
            UserDefaults.standard.set(data, forKey: key(for: statue))
            print("📌 Developer anchors saved for \(statue.title) (\(anchors.count) points)")
        }
    }
    
    static func load(for statue: Statue) -> [DevAnchorData]? {
        guard let data = UserDefaults.standard.data(forKey: key(for: statue)),
              let anchors = try? JSONDecoder().decode([DevAnchorData].self, from: data),
              !anchors.isEmpty else {
            return nil
        }
        return anchors
    }
    
    static func hasData(for statue: Statue) -> Bool {
        load(for: statue) != nil
    }
    
    static func clear(for statue: Statue) {
        UserDefaults.standard.removeObject(forKey: key(for: statue))
        print("📌 Developer anchors cleared for \(statue.title)")
    }
}
