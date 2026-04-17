//
//  AnnotationCardsOverlay.swift
//  Sansarana
//
//  Floating AR info cards positioned at screen edges with dashed leader lines
//  connecting back to annotation dots on the statue. The statue remains fully visible.
//

import SwiftUI

// MARK: - Floating Annotation Cards Overlay

struct FloatingAnnotationCardsOverlay: View {
    let statue: Statue?
    let annotations: [Annotation]
    /// Screen positions from raycast-anchored 3D points (Approach 2).
    let anchoredScreenPositions: [String: CGPoint]
    /// Current detections for fallback bounding-box positions (Approach 1).
    let detections: [StatueDetectionResult]
    @Binding var selectedAnnotation: Annotation?
    
    /// Card width constant
    private let cardWidth: CGFloat = 155
    
    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            
            if let statue = statue {
                let annotationPoints = statue.annotationPoints
                
                // First pass: collect all dot positions so we can do vertical spacing
                let dotPositions: [(Int, CGPoint)] = annotations.enumerated().compactMap { index, _ in
                    guard index < annotationPoints.count else { return nil }
                    let point = annotationPoints[index]
                    guard let pos = resolveScreenPosition(for: point, screenSize: geometry.size) else { return nil }
                    return (index, pos)
                }
                
                // Compute card Y positions with overlap avoidance
                let cardYPositions = computeCardYPositions(
                    dotPositions: dotPositions,
                    screenHeight: screenHeight
                )
                
                ZStack {
                    ForEach(Array(annotations.enumerated()), id: \.element.id) { index, annotation in
                        if index < annotationPoints.count,
                           let dotPos = dotPositions.first(where: { $0.0 == index })?.1,
                           let cardY = cardYPositions[index] {
                            
                            let isLeftSide = index % 2 == 0
                            let cardX = isLeftSide ? CGFloat(90) : screenWidth - 90
                            let cardEdgeX = isLeftSide ? cardX + cardWidth / 2 : cardX - cardWidth / 2
                            
                            // Dashed leader line from card edge to annotation dot
                            Path { path in
                                path.move(to: CGPoint(x: cardEdgeX, y: cardY))
                                path.addLine(to: CGPoint(x: dotPos.x, y: dotPos.y))
                            }
                            .stroke(
                                Color.white.opacity(0.4),
                                style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                            )
                            
                            // Card at screen edge
                            Button {
                                selectedAnnotation = annotation
                            } label: {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color.saffronGold)
                                        .frame(width: 8, height: 8)
                                    
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(annotation.title)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.white)
                                        
                                        Text(annotation.subtitle)
                                            .font(.caption2)
                                            .foregroundStyle(.white.opacity(0.8))
                                    }
                                    
                                    Spacer(minLength: 4)
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .frame(width: cardWidth)
                                .background {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(Color.saffronGold.opacity(0.3), lineWidth: 1)
                                        )
                                        .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
                                }
                            }
                            .buttonStyle(FloatingCardButtonStyle())
                            .position(x: cardX, y: cardY)
                            .transition(.opacity)
                        }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: anchoredScreenPositions.count)
    }
    
    // MARK: - Screen Position Resolution
    
    private func resolveScreenPosition(
        for point: AnnotationPoint,
        screenSize: CGSize
    ) -> CGPoint? {
        // Approach 2: Use projected 3D anchor position if available
        if let pos = anchoredScreenPositions[point.label] {
            return pos
        }
        
        // Approach 1: Fall back to bounding box relative position
        if let statue = statue,
           let detection = detections.first(where: { $0.statue == statue }) {
            let x = detection.screenRect.origin.x + point.relativeX * detection.screenRect.width
            let y = detection.screenRect.origin.y + point.relativeY * detection.screenRect.height
            let pos = CGPoint(x: x, y: y)
            
            if pos.x >= 0, pos.x <= screenSize.width,
               pos.y >= 0, pos.y <= screenSize.height {
                return pos
            }
        }
        
        return nil
    }
    
    // MARK: - Vertical Spacing
    
    /// Computes card Y positions, clamped and spaced to avoid overlap on the same side.
    private func computeCardYPositions(
        dotPositions: [(Int, CGPoint)],
        screenHeight: CGFloat
    ) -> [Int: CGFloat] {
        let minY: CGFloat = 180      // Below StatueInfoCard
        let maxY: CGFloat = screenHeight - 150 // Above tab bar
        let minSpacing: CGFloat = 55
        
        var result: [Int: CGFloat] = [:]
        // Track last Y for left side (even indices) and right side (odd indices)
        var lastLeftY: CGFloat = -1000
        var lastRightY: CGFloat = -1000
        
        // Sort by dot Y so we process top-to-bottom per side
        let sorted = dotPositions.sorted { $0.1.y < $1.1.y }
        
        for (index, dotPos) in sorted {
            var y = Swift.min(Swift.max(dotPos.y, minY), maxY)
            let isLeftSide = index % 2 == 0
            
            if isLeftSide {
                if y - lastLeftY < minSpacing {
                    y = lastLeftY + minSpacing
                }
                y = Swift.min(y, maxY)
                lastLeftY = y
            } else {
                if y - lastRightY < minSpacing {
                    y = lastRightY + minSpacing
                }
                y = Swift.min(y, maxY)
                lastRightY = y
            }
            
            result[index] = y
        }
        
        return result
    }
}

// MARK: - Button Style

private struct FloatingCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        FloatingAnnotationCardsOverlay(
            statue: .seatedBuddha,
            annotations: Statue.seatedBuddha.annotations,
            anchoredScreenPositions: [:],
            detections: [
                StatueDetectionResult(
                    statue: .seatedBuddha,
                    boundingBox: CGRect(x: 0.2, y: 0.3, width: 0.4, height: 0.5),
                    confidence: 0.95,
                    screenRect: CGRect(x: 60, y: 150, width: 250, height: 400)
                )
            ],
            selectedAnnotation: .constant(nil)
        )
    }
}
