//
//  AnchorPlacementOverlay.swift
//  Sansarana
//
//  Developer-mode overlay for dragging annotation anchor dots on the splat viewer.
//  Cards sit at left/right edges with dashed leader lines to dots on the model.
//

import SwiftUI
import simd

struct AnchorPlacementOverlay: View {
    let annotations: [Annotation]
    @Binding var editedPositions: [String: SIMD3<Float>]
    @Binding var cardPositions: [String: CGSize]
    let mvpMatrix: simd_float4x4
    let viewportSize: CGSize
    /// Whether saved anchor positions exist for this statue (affects initial layout)
    let hasSavedAnchors: Bool
    /// When false, dots and cards are displayed but not draggable (read-only mode)
    var isEditable: Bool = true
    /// The title of the currently highlighted annotation (used to show active card)
    var highlightedAnnotationTitle: String? = nil
    /// Callback when a card is tapped in read-only mode
    var onAnnotationTapped: ((Annotation) -> Void)? = nil
    
    // Dot dragging state
    @State private var dragOffsets: [String: CGSize] = [:]
    @State private var draggingAnnotation: String? = nil
    // Live 3D coordinate during dot drag
    @State private var dragLivePosition3D: [String: SIMD3<Float>] = [:]
    // Card dragging: in-flight offset (added to persisted cardPositions)
    @State private var cardDragOffsets: [String: CGSize] = [:]
    @State private var draggingCard: String? = nil
    
    private let cardWidth: CGFloat = 155
    private let edgePadding: CGFloat = 20
    
    var body: some View {
        GeometryReader { geometry in
            let screenSize = geometry.size
            
            // Resolve dot screen positions for every annotation
            let dotInfos: [(Int, Annotation, CGPoint)] = annotations.enumerated().map { index, annotation in
                let dotPos = resolveDotPosition(
                    for: annotation,
                    index: index,
                    totalCount: annotations.count,
                    screenSize: screenSize
                )
                return (index, annotation, dotPos)
            }
            
            // Compute card Y positions with overlap avoidance
            let cardYPositions = computeCardYPositions(
                dotInfos: dotInfos,
                screenHeight: screenSize.height
            )
            
            ZStack {
                ForEach(Array(dotInfos), id: \.1.id) { index, annotation, dotPos in
                    let dotOffset = dragOffsets[annotation.title] ?? .zero
                    let isDotDragging = draggingAnnotation == annotation.title
                    let isCardDragging = draggingCard == annotation.title
                    let isActive = isDotDragging || isCardDragging
                    let currentDotX = dotPos.x + dotOffset.width
                    let currentDotY = dotPos.y + dotOffset.height
                    
                    let isLeftSide = index % 2 == 0
                    let cardRestX = isLeftSide ? CGFloat(90) : screenSize.width - 90
                    let cardRestY = cardYPositions[index] ?? dotPos.y
                    
                    // Card position: rest + persisted offset + in-flight drag
                    let savedCardOffset = cardPositions[annotation.title] ?? .zero
                    let activeCardDrag = cardDragOffsets[annotation.title] ?? .zero
                    let cardCurrentX = cardRestX + savedCardOffset.width + activeCardDrag.width
                    let cardCurrentY = cardRestY + savedCardOffset.height + activeCardDrag.height
                    let cardEdgeX = isLeftSide ? cardCurrentX + cardWidth / 2 : cardCurrentX - cardWidth / 2
                    
                    // Edge card (draggable in edit mode, tappable in read-only mode)
                    let isHighlighted = highlightedAnnotationTitle == annotation.title
                    
                    // Dashed leader line from card edge to dot
                    Path { path in
                        path.move(to: CGPoint(x: cardEdgeX, y: cardCurrentY))
                        path.addLine(to: CGPoint(x: currentDotX, y: currentDotY))
                    }
                    .stroke(
                        Color.white.opacity(0.4),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                    )
                    
                    anchorCard(
                        annotation: annotation,
                        isActive: isActive,
                        isHighlighted: isHighlighted,
                        showDragIcon: isEditable
                    )
                    .scaleEffect(isCardDragging ? 0.9 : 1.0)
                    .opacity(isCardDragging ? 0.8 : 1.0)
                    .position(x: cardCurrentX, y: cardCurrentY)
                    .if(isEditable) { view in
                        view.gesture(
                            DragGesture()
                                .onChanged { value in
                                    draggingCard = annotation.title
                                    cardDragOffsets[annotation.title] = value.translation
                                }
                                .onEnded { value in
                                    let prev = cardPositions[annotation.title] ?? .zero
                                    cardPositions[annotation.title] = CGSize(
                                        width: prev.width + value.translation.width,
                                        height: prev.height + value.translation.height
                                    )
                                    cardDragOffsets[annotation.title] = .zero
                                    draggingCard = nil
                                }
                        )
                    }
                    .if(!isEditable) { view in
                        view.onTapGesture {
                            onAnnotationTapped?(annotation)
                        }
                    }
                    
                    // Dot on the model (draggable in edit mode only)
                    anchorDot(isActive: isActive)
                        .position(x: currentDotX, y: currentDotY)
                        .if(isEditable) { view in
                            view.gesture(
                                DragGesture()
                                    .onChanged { value in
                                        draggingAnnotation = annotation.title
                                        dragOffsets[annotation.title] = value.translation
                                        
                                        let liveScreenPt = CGPoint(
                                            x: dotPos.x + value.translation.width,
                                            y: dotPos.y + value.translation.height
                                        )
                                        let viewportPt = screenToViewport(liveScreenPt, screenSize: screenSize)
                                        dragLivePosition3D[annotation.title] = unproject(viewportPt, mvp: mvpMatrix, viewport: viewportSize)
                                    }
                                    .onEnded { value in
                                        let finalScreen = CGPoint(
                                            x: dotPos.x + value.translation.width,
                                            y: dotPos.y + value.translation.height
                                        )
                                        let viewportPt = screenToViewport(finalScreen, screenSize: screenSize)
                                        let newPos3D = unproject(viewportPt, mvp: mvpMatrix, viewport: viewportSize)
                                        editedPositions[annotation.title] = newPos3D
                                        
                                        dragOffsets[annotation.title] = .zero
                                        dragLivePosition3D[annotation.title] = nil
                                        draggingAnnotation = nil
                                    }
                            )
                        }
                    
                    // Live coordinate readout while dragging dot (edit mode only)
                    if isEditable, isDotDragging, let livePos = dragLivePosition3D[annotation.title] {
                        Text(String(format: "(%.3f, %.3f, %.3f)", livePos.x, livePos.y, livePos.z))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.7), in: Capsule())
                            .position(x: currentDotX, y: currentDotY - 22)
                    }
                }
            }
        }
        .allowsHitTesting(isEditable || onAnnotationTapped != nil)
    }
    
    // MARK: - Dot Position Resolution
    
    /// Resolves the screen position for an annotation dot.
    /// If saved anchors exist, project from 3D; otherwise use evenly-spaced defaults.
    /// Off-screen projections are clamped to viewport edges.
    private func resolveDotPosition(
        for annotation: Annotation,
        index: Int,
        totalCount: Int,
        screenSize: CGSize
    ) -> CGPoint {
        if hasSavedAnchors {
            let pos3D = editedPositions[annotation.title] ?? annotation.position3D
            if let projected = project(pos3D, mvp: mvpMatrix, viewport: viewportSize) {
                // Convert viewport coords to screen coords
                let screenPt = viewportToScreen(projected, screenSize: screenSize)
                // Clamp to visible area
                return clampToViewport(screenPt, screenSize: screenSize)
            }
        }
        
        // Default: spread dots evenly across the model area
        return defaultDotPosition(index: index, totalCount: totalCount, screenSize: screenSize)
    }
    
    /// Default evenly-spaced positions for unsaved dots
    private func defaultDotPosition(index: Int, totalCount: Int, screenSize: CGSize) -> CGPoint {
        // 2-column grid layout within the center area of the viewer
        let col = index % 2       // 0 = left column, 1 = right column
        let row = index / 2       // row index
        let totalRows = max((totalCount + 1) / 2, 1)
        
        let xFraction: CGFloat = col == 0 ? 0.30 : 0.70
        let yStart: CGFloat = 0.20
        let yEnd: CGFloat = 0.80
        let yFraction: CGFloat
        if totalRows == 1 {
            yFraction = 0.5
        } else {
            yFraction = yStart + (yEnd - yStart) * CGFloat(row) / CGFloat(totalRows - 1)
        }
        
        return CGPoint(
            x: screenSize.width * xFraction,
            y: screenSize.height * yFraction
        )
    }
    
    /// Clamp a point to stay within viewport bounds with padding
    private func clampToViewport(_ point: CGPoint, screenSize: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(point.x, edgePadding), screenSize.width - edgePadding),
            y: min(max(point.y, edgePadding), screenSize.height - edgePadding)
        )
    }
    
    // MARK: - Coordinate Conversion
    
    /// Convert viewport (Metal drawable) coordinates to SwiftUI screen coordinates
    private func viewportToScreen(_ viewportPt: CGPoint, screenSize: CGSize) -> CGPoint {
        CGPoint(
            x: viewportPt.x * screenSize.width / viewportSize.width,
            y: viewportPt.y * screenSize.height / viewportSize.height
        )
    }
    
    /// Convert SwiftUI screen coordinates to viewport (Metal drawable) coordinates
    private func screenToViewport(_ screenPt: CGPoint, screenSize: CGSize) -> CGPoint {
        CGPoint(
            x: screenPt.x * viewportSize.width / screenSize.width,
            y: screenPt.y * viewportSize.height / screenSize.height
        )
    }
    
    // MARK: - Card Y Spacing
    
    private func computeCardYPositions(
        dotInfos: [(Int, Annotation, CGPoint)],
        screenHeight: CGFloat
    ) -> [Int: CGFloat] {
        let minY: CGFloat = 40
        let maxY: CGFloat = screenHeight - 40
        let minSpacing: CGFloat = 55
        
        var result: [Int: CGFloat] = [:]
        var lastLeftY: CGFloat = -1000
        var lastRightY: CGFloat = -1000
        
        // Sort by dot Y position for top-to-bottom processing
        let sorted = dotInfos.sorted { $0.2.y < $1.2.y }
        
        for (index, _, dotPos) in sorted {
            var y = min(max(dotPos.y, minY), maxY)
            let isLeftSide = index % 2 == 0
            
            if isLeftSide {
                if y - lastLeftY < minSpacing {
                    y = lastLeftY + minSpacing
                }
                y = min(y, maxY)
                lastLeftY = y
            } else {
                if y - lastRightY < minSpacing {
                    y = lastRightY + minSpacing
                }
                y = min(y, maxY)
                lastRightY = y
            }
            
            result[index] = y
        }
        
        return result
    }
    
    // MARK: - Subviews
    
    /// Glassmorphic edge card matching AR overlay style
    @ViewBuilder
    private func anchorCard(annotation: Annotation, isActive: Bool, isHighlighted: Bool = false, showDragIcon: Bool = true) -> some View {
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
            
            if showDragIcon {
                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(isActive ? 1.0 : 0.4))
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: cardWidth)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            Color.saffronGold,
                            lineWidth: isHighlighted ? 2 : 0
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
        }
    }
    
    /// Gold draggable dot on the model
    @ViewBuilder
    private func anchorDot(isActive: Bool) -> some View {
        Circle()
            .fill(Color.saffronGold)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
            .shadow(color: isActive ? Color.saffronGold.opacity(0.6) : .clear, radius: 6)
            .scaleEffect(isActive ? 1.5 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isActive)
    }
    
    // MARK: - Projection Helpers
    
    /// Project a 3D point to 2D viewport coordinates using the MVP matrix
    private func project(_ position3D: SIMD3<Float>, mvp: simd_float4x4, viewport: CGSize) -> CGPoint? {
        let clip = mvp * SIMD4<Float>(position3D.x, position3D.y, position3D.z, 1.0)
        guard clip.w > 0 else { return nil } // Behind camera
        let ndc = SIMD3<Float>(clip.x, clip.y, clip.z) / clip.w
        let screenX = (ndc.x + 1.0) * 0.5 * Float(viewport.width)
        let screenY = (1.0 - ndc.y) * 0.5 * Float(viewport.height)
        return CGPoint(x: CGFloat(screenX), y: CGFloat(screenY))
    }
    
    /// Unproject a 2D viewport point back to 3D model space
    private func unproject(_ screenPoint: CGPoint, mvp: simd_float4x4, viewport: CGSize) -> SIMD3<Float> {
        let ndcX = Float(screenPoint.x / viewport.width) * 2.0 - 1.0
        let ndcY = 1.0 - Float(screenPoint.y / viewport.height) * 2.0
        
        let invMVP = mvp.inverse
        
        let nearClip = invMVP * SIMD4<Float>(ndcX, ndcY, -1.0, 1.0)
        let farClip = invMVP * SIMD4<Float>(ndcX, ndcY, 1.0, 1.0)
        
        let nearWorld = SIMD3<Float>(nearClip.x, nearClip.y, nearClip.z) / nearClip.w
        let farWorld = SIMD3<Float>(farClip.x, farClip.y, farClip.z) / farClip.w
        
        let rayDir = normalize(farWorld - nearWorld)
        
        // Find closest approach to origin (model center) along the ray
        let t = -dot(nearWorld, rayDir)
        return nearWorld + rayDir * max(t, 0)
    }
}

// MARK: - Conditional View Modifier

private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
