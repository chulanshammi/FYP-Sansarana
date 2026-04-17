//
//  DeveloperModeOverlay.swift
//  Sansarana
//
//  Developer mode overlay for the AR camera view. Allows tap-to-place
//  and drag-to-refine annotation anchors on detected statues at Gal Viharaya.
//  Anchors are saved as offsets relative to the bounding box center raycast,
//  making them persistent across sessions.
//

import SwiftUI

struct DeveloperModeOverlay: View {
    @ObservedObject var viewModel: ARViewModel
    
    /// Callback to request a raycast from a screen point.
    /// Returns the world position if the raycast hits, nil otherwise.
    var onRequestRaycast: ((CGPoint) -> SIMD3<Float>?)?
    
    /// Callback to request establishing the reference point (bbox center raycast).
    var onEstablishReference: (() -> Void)?
    
    @State private var showSaveConfirmation = false
    @State private var showClearConfirmation = false
    
    var body: some View {
        ZStack {
            // Top banner
            VStack(spacing: 0) {
                devBanner
                    .padding(.top, 50)
                
                // Status message
                if !viewModel.devStatusMessage.isEmpty {
                    Text(viewModel.devStatusMessage)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.7), in: Capsule())
                        .padding(.top, 8)
                        .transition(.opacity)
                        .animation(.easeInOut, value: viewModel.devStatusMessage)
                }
                
                Spacer()
            }
            
            // Center crosshair when placing
            if viewModel.devPlacingAnnotation != nil {
                crosshairReticle
            }
            
            // Placed anchor indicators
            placedAnchorDots
            
            // Bottom controls
            VStack {
                Spacer()
                bottomControls
                    .padding(.bottom, 160)
            }
        }
    }
    
    // MARK: - Developer Banner
    
    private var devBanner: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .fill(Color.red.opacity(0.5))
                        .frame(width: 16, height: 16)
                        .scaleEffect(viewModel.devReferenceEstablished ? 1.0 : 1.5)
                        .opacity(viewModel.devReferenceEstablished ? 0.5 : 0.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: viewModel.devReferenceEstablished)
                )
            
            Text("DEVELOPER MODE")
                .font(.caption)
                .fontWeight(.bold)
                .tracking(1)
            
            if viewModel.devReferenceEstablished {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.red.opacity(0.6), lineWidth: 1)
                )
        }
    }
    
    // MARK: - Crosshair Reticle
    
    private var crosshairReticle: some View {
        VStack(spacing: 4) {
            if let label = viewModel.devPlacingAnnotation {
                Text("Tap on statue to place:")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
                Text(label)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.saffronGold)
            }
            
            ZStack {
                // Horizontal line
                Rectangle()
                    .fill(Color.saffronGold.opacity(0.6))
                    .frame(width: 30, height: 1)
                
                // Vertical line
                Rectangle()
                    .fill(Color.saffronGold.opacity(0.6))
                    .frame(width: 1, height: 30)
                
                // Center dot
                Circle()
                    .stroke(Color.saffronGold, lineWidth: 1.5)
                    .frame(width: 12, height: 12)
            }
        }
    }
    
    // MARK: - Placed Anchor Dots
    
    /// Shows small indicators for annotations that have been placed in this session.
    private var placedAnchorDots: some View {
        GeometryReader { _ in
            // Dots are rendered by the Coordinator via the existing annotation system.
            // This overlay just shows the labels of what's placed/unplaced.
            EmptyView()
        }
    }
    
    // MARK: - Bottom Controls
    
    private var bottomControls: some View {
        VStack(spacing: 12) {
            // Reference point status
            if !viewModel.devReferenceEstablished {
                Button(action: { onEstablishReference?() }) {
                    Label("Establish Reference Point", systemImage: "scope")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            
            // Annotation selection pills
            if let statue = viewModel.primaryStatue, viewModel.devReferenceEstablished {
                annotationPills(for: statue)
            }
            
            // Action buttons
            if viewModel.devReferenceEstablished {
                HStack(spacing: 12) {
                    Button(action: {
                        viewModel.saveDevAnchors()
                        showSaveConfirmation = true
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            showSaveConfirmation = false
                        }
                    }) {
                        Label(
                            showSaveConfirmation ? "Saved!" : "Save All",
                            systemImage: showSaveConfirmation ? "checkmark.circle.fill" : "square.and.arrow.down"
                        )
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(showSaveConfirmation ? .green : Color.saffronGold)
                    .disabled(viewModel.devPlacedAnchors.isEmpty)
                    
                    Button(action: {
                        showClearConfirmation = true
                    }) {
                        Label("Clear All", systemImage: "trash")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                
                // Placement count
                let total = viewModel.primaryStatue?.annotations.count ?? 0
                let placed = viewModel.devPlacedAnchors.count
                Text("\(placed)/\(total) anchors placed")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .alert("Clear All Anchors?", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                viewModel.clearDevAnchors()
            }
        } message: {
            Text("This will remove all saved anchor positions for this statue. You'll need to re-calibrate on-site.")
        }
    }
    
    // MARK: - Annotation Pills
    
    private func annotationPills(for statue: Statue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select annotation to place:")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            // Use a wrapping layout via flexible grid
            let columns = [
                GridItem(.flexible()),
                GridItem(.flexible())
            ]
            
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(statue.annotations) { annotation in
                    let isPlaced = viewModel.devPlacedAnchors[annotation.title] != nil
                    let isSelected = viewModel.devPlacingAnnotation == annotation.title
                    
                    Button(action: {
                        if isSelected {
                            viewModel.devPlacingAnnotation = nil
                        } else {
                            viewModel.devPlacingAnnotation = annotation.title
                            viewModel.devStatusMessage = "Tap on the statue where \"\(annotation.title)\" should appear."
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: isPlaced ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 10))
                                .foregroundStyle(isPlaced ? .green : .white.opacity(0.4))
                            
                            Text(annotation.title)
                                .font(.caption2)
                                .fontWeight(isSelected ? .bold : .regular)
                                .lineLimit(1)
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected ? Color.saffronGold.opacity(0.3) : .white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            isSelected ? Color.saffronGold : .clear,
                                            lineWidth: 1.5
                                        )
                                )
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        DeveloperModeOverlay(viewModel: ARViewModel())
    }
}
