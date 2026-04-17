//
//  BoundingBoxOverlay.swift
//  Sansarana
//
//  Draws bounding boxes over detected statues on the camera feed.
//

import SwiftUI

struct BoundingBoxOverlay: View {
    let detections: [StatueDetectionResult]
    let primaryStatue: Statue?
    var onSelect: (Statue) -> Void
    
    var body: some View {
        ZStack {
            ForEach(detections) { detection in
                BoundingBoxView(
                    detection: detection,
                    isPrimary: detection.statue == primaryStatue
                )
                .onTapGesture {
                    onSelect(detection.statue)
                }
            }
        }
        .allowsHitTesting(true)
        .animation(.easeInOut(duration: 0.2), value: detections.map(\.screenRect))
    }
}

// MARK: - Single Bounding Box

private struct BoundingBoxView: View {
    let detection: StatueDetectionResult
    let isPrimary: Bool
    
    var body: some View {
        let rect = detection.screenRect
        
        ZStack(alignment: .top) {
            // Bounding box outline
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isPrimary ? Color.saffronGold : Color.saffronGold.opacity(0.5),
                    lineWidth: isPrimary ? 2.5 : 1.5
                )
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
            
            // Label pill at the top of the bounding box
            LabelPill(
                name: detection.statue.title,
                confidence: detection.confidence,
                isPrimary: isPrimary
            )
            .position(x: rect.midX, y: rect.minY - 14)
        }
    }
}

// MARK: - Label Pill

private struct LabelPill: View {
    let name: String
    let confidence: Float
    let isPrimary: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            if isPrimary {
                Circle()
                    .fill(Color.saffronGold)
                    .frame(width: 6, height: 6)
            }
            
            Text(name)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            
            Text("\(Int(confidence * 100))%")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.saffronGold.opacity(isPrimary ? 0.6 : 0.3), lineWidth: 1)
        )
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        BoundingBoxOverlay(
            detections: [
                StatueDetectionResult(
                    statue: .seatedBuddha,
                    boundingBox: CGRect(x: 0.2, y: 0.3, width: 0.4, height: 0.5),
                    confidence: 0.95,
                    screenRect: CGRect(x: 80, y: 200, width: 200, height: 300)
                )
            ],
            primaryStatue: .seatedBuddha,
            onSelect: { _ in }
        )
    }
}
