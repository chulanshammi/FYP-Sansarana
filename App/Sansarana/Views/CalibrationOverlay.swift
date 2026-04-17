//
//  CalibrationOverlay.swift
//  Sansarana
//
//  Approach 3: On-site calibration mode for fine-tuning annotation positions
//  at Gal Viharaya. Shows draggable annotation markers and XYZ offset sliders.
//

import SwiftUI

struct CalibrationOverlay: View {
    @ObservedObject var viewModel: ARViewModel
    
    @State private var dragOffsets: [String: CGSize] = [:]
    @State private var selectedPoint: String?
    @State private var offsetX: Float = 0.0
    @State private var offsetY: Float = 0.0
    @State private var offsetZ: Float = 0.0
    
    var body: some View {
        ZStack {
            // Top banner
            VStack {
                CalibrationBanner()
                Spacer()
            }
            
            // Draggable annotation markers for the primary statue
            if let statue = viewModel.primaryStatue,
               let detection = viewModel.detectedStatues.first(where: { $0.statue == statue }) {
                ForEach(statue.annotationPoints) { point in
                    DraggableMarker(
                        label: point.label,
                        basePosition: screenPosition(for: point, in: detection.screenRect),
                        dragOffset: Binding(
                            get: { dragOffsets[point.label] ?? .zero },
                            set: { dragOffsets[point.label] = $0 }
                        ),
                        isSelected: selectedPoint == point.label
                    )
                    .onTapGesture {
                        selectedPoint = point.label
                        // Load existing calibration offset if any.
                        if let statue = viewModel.primaryStatue {
                            let existing = viewModel.getCalibrationData(for: statue)
                            if let pos = existing.first(where: { $0.label == point.label }) {
                                offsetX = pos.offset.x
                                offsetY = pos.offset.y
                                offsetZ = pos.offset.z
                            } else {
                                offsetX = 0; offsetY = 0; offsetZ = 0
                            }
                        }
                    }
                }
            }
            
            // Bottom controls
            VStack {
                Spacer()
                
                if let pointLabel = selectedPoint {
                    CalibrationControls(
                        pointLabel: pointLabel,
                        offsetX: $offsetX,
                        offsetY: $offsetY,
                        offsetZ: $offsetZ,
                        onSave: saveCurrentPoint,
                        onSaveAll: saveAllCalibration,
                        onCopy: copyPositions
                    )
                    .padding(.bottom, 160)
                }
            }
        }
    }
    
    private func screenPosition(for point: AnnotationPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.origin.x + point.relativeX * rect.width,
            y: rect.origin.y + point.relativeY * rect.height
        )
    }
    
    private func saveCurrentPoint() {
        guard let statue = viewModel.primaryStatue,
              let label = selectedPoint else { return }
        
        var positions = viewModel.getCalibrationData(for: statue)
        positions.removeAll { $0.label == label }
        positions.append(CalibratedPosition(
            label: label,
            offset: SIMD3<Float>(offsetX, offsetY, offsetZ)
        ))
        viewModel.saveCalibrationData(for: statue, positions: positions)
        print("⚙️ Calibration saved for point: \(label)")
    }
    
    private func saveAllCalibration() {
        guard let statue = viewModel.primaryStatue else { return }
        
        var positions: [CalibratedPosition] = []
        for point in statue.annotationPoints {
            let offset: SIMD3<Float>
            if point.label == selectedPoint {
                offset = SIMD3<Float>(offsetX, offsetY, offsetZ)
            } else if let existing = viewModel.getCalibrationData(for: statue).first(where: { $0.label == point.label }) {
                offset = existing.offset
            } else {
                offset = .zero
            }
            positions.append(CalibratedPosition(label: point.label, offset: offset))
        }
        viewModel.saveCalibrationData(for: statue, positions: positions)
        print("⚙️ All calibration data saved for \(statue.title)")
    }
    
    private func copyPositions() {
        guard let statue = viewModel.primaryStatue else { return }
        viewModel.copyCalibrationToClipboard(for: statue)
    }
}

// MARK: - Calibration Banner

private struct CalibrationBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "scope")
                .font(.caption)
            Text("Calibration Mode")
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.saffronGold.opacity(0.6), lineWidth: 1)
                )
        }
        .padding(.top, 50)
    }
}

// MARK: - Draggable Marker

private struct DraggableMarker: View {
    let label: String
    let basePosition: CGPoint
    @Binding var dragOffset: CGSize
    let isSelected: Bool
    
    @GestureState private var activeDrag: CGSize = .zero
    
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    isSelected ? Color.saffronGold.opacity(0.8) : Color.black.opacity(0.5),
                    in: RoundedRectangle(cornerRadius: 4)
                )
            
            Circle()
                .fill(isSelected ? Color.saffronGold : Color.white)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color.saffronGold, lineWidth: isSelected ? 2 : 1)
                        .frame(width: 18, height: 18)
                )
        }
        .position(
            x: basePosition.x + dragOffset.width + activeDrag.width,
            y: basePosition.y + dragOffset.height + activeDrag.height
        )
        .gesture(
            DragGesture()
                .updating($activeDrag) { value, state, _ in
                    state = value.translation
                }
                .onEnded { value in
                    dragOffset.width += value.translation.width
                    dragOffset.height += value.translation.height
                }
        )
    }
}

// MARK: - Calibration Controls

private struct CalibrationControls: View {
    let pointLabel: String
    @Binding var offsetX: Float
    @Binding var offsetY: Float
    @Binding var offsetZ: Float
    var onSave: () -> Void
    var onSaveAll: () -> Void
    var onCopy: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Calibrating: \(pointLabel)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                Spacer()
            }
            
            // XYZ offset sliders
            CalibrationSlider(title: "X", value: $offsetX, range: -3...3)
            CalibrationSlider(title: "Y", value: $offsetY, range: -3...3)
            CalibrationSlider(title: "Z", value: $offsetZ, range: -3...3)
            
            HStack(spacing: 12) {
                Button(action: onSave) {
                    Label("Save Point", systemImage: "checkmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.saffronGold)
                
                Button(action: onSaveAll) {
                    Label("Save All", systemImage: "square.and.arrow.down")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.white)
                
                Spacer()
                
                Button(action: onCopy) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.white)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

private struct CalibrationSlider: View {
    let title: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    
    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .frame(width: 14)
            
            Slider(value: $value, in: range)
                .tint(Color.saffronGold)
            
            Text(String(format: "%.2f", value))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        CalibrationOverlay(viewModel: ARViewModel())
    }
}
