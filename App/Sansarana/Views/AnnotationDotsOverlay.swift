//
//  AnnotationDotsOverlay.swift
//  Sansarana
//
//  Screen-space annotation dot indicators that overlay the AR camera feed.
//  Dots appear for the primary statue's annotation points and fade out
//  when upgraded to 3D anchors (Approach 2).
//

import SwiftUI

struct AnnotationDotsOverlay: View {
    let detections: [StatueDetectionResult]
    let primaryStatue: Statue?
    /// Labels of points that have been upgraded to 3D world anchors.
    let upgradedPoints: Set<String>
    /// Triggers the annotation detail card flow.
    var onSelectAnnotation: ((String) -> Void)?
    
    /// Number of consecutive frames the primary statue has been detected (for stabilisation).
    @State private var stableFrameCount: Int = 0
    @State private var lastPrimaryId: String?
    
    var body: some View {
        ZStack {
            if let statue = primaryStatue,
               let detection = detections.first(where: { $0.statue == statue }) {
                ForEach(statue.annotationPoints) { point in
                    let screenPos = screenPosition(for: point, in: detection.screenRect)
                    
                    if !upgradedPoints.contains(point.label) && stableFrameCount >= 2 {
                        AnnotationDot(label: point.label, position: screenPos)
                            .transition(.opacity)
                            .onTapGesture {
                                onSelectAnnotation?(point.label)
                            }
                    }
                }
            }
        }
        .allowsHitTesting(true)
        .animation(.easeInOut(duration: 0.3), value: stableFrameCount)
        .onChange(of: detections.map(\.screenRect)) { _, _ in
            updateStability()
        }
    }
    
    private func screenPosition(for point: AnnotationPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.origin.x + point.relativeX * rect.width,
            y: rect.origin.y + point.relativeY * rect.height
        )
    }
    
    private func updateStability() {
        guard let statue = primaryStatue,
              let detection = detections.first(where: { $0.statue == statue }) else {
            stableFrameCount = 0
            lastPrimaryId = nil
            return
        }
        
        // Check if primary statue is consistent across frames.
        if lastPrimaryId == detection.id {
            stableFrameCount += 1
        } else {
            stableFrameCount = 1
        }
        lastPrimaryId = detection.id
    }
}

// MARK: - Single Annotation Dot

private struct AnnotationDot: View {
    let label: String
    let position: CGPoint
    
    var body: some View {
        VStack(spacing: 2) {
            // Label pill
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.ultraThinMaterial, in: Capsule())
            
            // Leader line
            Rectangle()
                .fill(Color.white.opacity(0.5))
                .frame(width: 1, height: 12)
            
            // Dot indicator
            ZStack {
                Circle()
                    .fill(Color.saffronGold)
                    .frame(width: 8, height: 8)
                
                Circle()
                    .stroke(Color.white, lineWidth: 1.5)
                    .frame(width: 10, height: 10)
            }
        }
        .position(position)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        AnnotationDotsOverlay(
            detections: [
                StatueDetectionResult(
                    statue: .seatedBuddha,
                    boundingBox: CGRect(x: 0.2, y: 0.3, width: 0.4, height: 0.5),
                    confidence: 0.95,
                    screenRect: CGRect(x: 60, y: 150, width: 250, height: 400)
                )
            ],
            primaryStatue: .seatedBuddha,
            upgradedPoints: []
        )
    }
}
