//
//  ContentView.swift
//  Sansarana
//
//  Created by Chulan Shammi on 2026-03-18.
//

import SwiftUI
import MetalSplatter
import MetalKit
import simd

struct ContentView: View {
    var body: some View {
        ARCameraView()
    }
}

struct SplatView: View {
    @Binding var renderer: SplatRenderer?
    var cameraPosition: SIMD3<Float> = SIMD3<Float>(0, 0.5, 2.0)
    var centerOffset: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    var baseRotation: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    var modelRotation: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    var modelPosition: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    var modelScale: Float = 1.0
    @Binding var gestureRotationX: Float
    @Binding var gestureRotationY: Float
    @Binding var zoomScale: Float
    @Binding var cameraOrbitX: Float
    @Binding var cameraOrbitY: Float
    var onMVPMatrix: ((simd_float4x4, CGSize) -> Void)?
    
    var body: some View {
        MetalKitView(
            renderer: $renderer,
            cameraPosition: cameraPosition,
            centerOffset: centerOffset,
            baseRotation: baseRotation,
            modelRotation: modelRotation,
            modelPosition: modelPosition,
            modelScale: modelScale,
            gestureRotationX: $gestureRotationX,
            gestureRotationY: $gestureRotationY,
            zoomScale: $zoomScale,
            cameraOrbitX: $cameraOrbitX,
            cameraOrbitY: $cameraOrbitY,
            onMVPMatrix: onMVPMatrix
        )
    }
}

#if os(iOS) || os(visionOS)
import UIKit

struct MetalKitView: UIViewRepresentable {
    @Binding var renderer: SplatRenderer?
    var cameraPosition: SIMD3<Float> = SIMD3<Float>(0, 0.5, 2.0)
    var centerOffset: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    var baseRotation: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    var modelRotation: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    var modelPosition: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    var modelScale: Float = 1.0
    @Binding var gestureRotationX: Float
    @Binding var gestureRotationY: Float
    @Binding var zoomScale: Float
    @Binding var cameraOrbitX: Float
    @Binding var cameraOrbitY: Float
    var onMVPMatrix: ((simd_float4x4, CGSize) -> Void)?
    
    func makeUIView(context: Context) -> MTKView {
        let metalView = MTKView()
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        
        metalView.device = device
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.depthStencilPixelFormat = .depth32Float
        metalView.sampleCount = 1
        metalView.clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        metalView.delegate = context.coordinator
        metalView.enableSetNeedsDisplay = false
        metalView.isPaused = false
        metalView.preferredFramesPerSecond = 60
        
        if let existingRenderer = renderer {
            context.coordinator.renderer = existingRenderer
        }
        
        return metalView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        if let newRenderer = renderer, context.coordinator.renderer !== newRenderer {
            context.coordinator.renderer = newRenderer
        }
        
        context.coordinator.cameraPosition = cameraPosition
        context.coordinator.centerOffset = centerOffset
        context.coordinator.baseRotation = baseRotation
        context.coordinator.sliderRotation = modelRotation
        context.coordinator.modelPosition = modelPosition
        context.coordinator.modelScale = modelScale
        context.coordinator.onMVPMatrix = onMVPMatrix
        
        // Sync slider/config-driven values into the coordinator
        context.coordinator.gestureRotationX = gestureRotationX
        context.coordinator.gestureRotationY = gestureRotationY
        context.coordinator.zoomScale = zoomScale
        context.coordinator.cameraOrbitX = cameraOrbitX
        context.coordinator.cameraOrbitY = cameraOrbitY
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        var renderer: SplatRenderer?
        private var commandQueue: MTLCommandQueue?
        private var viewMatrix = matrix_identity_float4x4
        private var projectionMatrix = matrix_identity_float4x4
        
        // Parameters from SwiftUI (config panel sliders)
        var cameraPosition: SIMD3<Float> = SIMD3<Float>(0, 0.5, 2.0)
        var centerOffset: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
        var baseRotation: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
        var sliderRotation: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
        var modelPosition: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
        var modelScale: Float = 1.0
        
        // Config-driven state (set from SwiftUI via updateUIView)
        var gestureRotationX: Float = 0.0
        var gestureRotationY: Float = 0.0
        var zoomScale: Float = 1.0
        var cameraOrbitX: Float = 0.0
        var cameraOrbitY: Float = 0.0
        
        // MVP matrix callback for anchor placement overlay
        var onMVPMatrix: ((simd_float4x4, CGSize) -> Void)?
        
        // MARK: - MTKViewDelegate
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            let aspect = Float(size.width / size.height)
            projectionMatrix = makePerspectiveMatrix(fovRadians: .pi / 3, aspect: aspect, nearZ: 0.01, farZ: 200.0)
        }
        
        func draw(in view: MTKView) {
            guard let renderer = renderer else { return }
            
            if commandQueue == nil {
                commandQueue = view.device?.makeCommandQueue()
            }
            
            guard let commandQueue = commandQueue,
                  let commandBuffer = commandQueue.makeCommandBuffer(),
                  let drawable = view.currentDrawable,
                  let renderPassDescriptor = view.currentRenderPassDescriptor else {
                return
            }
            
            // Combine all rotations: base → slider → gesture
            let totalUserRotation = SIMD3<Float>(
                sliderRotation.x + gestureRotationX,
                sliderRotation.y + gestureRotationY,
                sliderRotation.z
            )
            
            // Apply zoom as model scale multiplier (avoids camera clipping)
            let modelTransform = makeModelTransform(
                position: modelPosition,
                centerOffset: centerOffset,
                baseRotation: baseRotation,
                userRotation: totalUserRotation,
                scale: modelScale * zoomScale
            )
            
            // Apply camera orbit: rotate the camera position around the model center
            // The model is centered at origin by centerOffset, so orbit around origin + position offset
            let target = modelPosition
            let orbitOffset = cameraPosition - target
            let orbitRadius = length(orbitOffset)
            // Start from the base camera direction and apply orbit angles
            let baseYaw = atan2(orbitOffset.x, orbitOffset.z)
            let basePitch = asin(orbitOffset.y / max(orbitRadius, 0.001))
            let yaw = baseYaw + cameraOrbitX
            let pitch = basePitch + cameraOrbitY
            let orbitedCamera = target + SIMD3<Float>(
                orbitRadius * cos(pitch) * sin(yaw),
                orbitRadius * sin(pitch),
                orbitRadius * cos(pitch) * cos(yaw)
            )
            let up = simd_float3(0, 1, 0)
            viewMatrix = makeLookAtMatrix(eye: orbitedCamera, target: target, up: up)
            viewMatrix = viewMatrix * modelTransform
            
            let aspect = Float(view.drawableSize.width / view.drawableSize.height)
            projectionMatrix = makePerspectiveMatrix(fovRadians: .pi / 3, aspect: aspect, nearZ: 0.01, farZ: 200.0)
            
            // Expose MVP matrix to SwiftUI for anchor projection/unprojection
            let mvpMatrix = projectionMatrix * viewMatrix
            let viewportSize = CGSize(width: view.drawableSize.width, height: view.drawableSize.height)
            DispatchQueue.main.async { [weak self] in
                self?.onMVPMatrix?(mvpMatrix, viewportSize)
            }
            
            let viewport = SplatRenderer.ViewportDescriptor(
                viewport: MTLViewport(
                    originX: 0, originY: 0,
                    width: Double(view.drawableSize.width),
                    height: Double(view.drawableSize.height),
                    znear: 0.0, zfar: 1.0
                ),
                projectionMatrix: projectionMatrix,
                viewMatrix: viewMatrix,
                screenSize: SIMD2<Int>(Int(view.drawableSize.width), Int(view.drawableSize.height))
            )
            
            do {
                try renderer.render(
                    viewports: [viewport],
                    colorTexture: drawable.texture,
                    colorStoreAction: .store,
                    depthTexture: renderPassDescriptor.depthAttachment.texture!,
                    rasterizationRateMap: nil,
                    renderTargetArrayLength: 0,
                    to: commandBuffer
                )
                
                commandBuffer.present(drawable)
                commandBuffer.commit()
            } catch {
                print("Render error: \(error)")
            }
        }
        
        // MARK: - Matrix Helpers
        
        private func makeModelTransform(position: SIMD3<Float>, centerOffset: SIMD3<Float>, baseRotation: SIMD3<Float>, userRotation: SIMD3<Float>, scale: Float) -> simd_float4x4 {
            // Transform order (rightmost applied first to vertices):
            // Position * UserRotation * Scale * BaseRotation * CenterOffset
            //
            // 1. CenterOffset: translate PLY centroid to origin
            // 2. BaseRotation: coordinate convention correction (e.g., COLMAP → Metal)
            // 3. Scale: model scale * zoom
            // 4. UserRotation: slider + gesture rotation
            // 5. Position: model position offset
            
            var transform = matrix_identity_float4x4
            
            // Position (outermost — final world placement)
            transform.columns.3 = simd_float4(position.x, position.y, position.z, 1)
            
            // User rotation (applied after correction)
            let userRotX = makeRotationMatrixX(angle: userRotation.x)
            let userRotY = makeRotationMatrixY(angle: userRotation.y)
            let userRotZ = makeRotationMatrixZ(angle: userRotation.z)
            transform = transform * userRotY * userRotX * userRotZ
            
            // Scale
            let scaleMatrix = simd_float4x4(
                simd_float4(scale, 0, 0, 0),
                simd_float4(0, scale, 0, 0),
                simd_float4(0, 0, scale, 0),
                simd_float4(0, 0, 0, 1)
            )
            transform = transform * scaleMatrix
            
            // Base rotation (PLY orientation/coordinate correction)
            let baseRotX = makeRotationMatrixX(angle: baseRotation.x)
            let baseRotY = makeRotationMatrixY(angle: baseRotation.y)
            let baseRotZ = makeRotationMatrixZ(angle: baseRotation.z)
            transform = transform * baseRotZ * baseRotY * baseRotX
            
            // Center offset (innermost — translate PLY centroid to origin)
            var centerTranslation = matrix_identity_float4x4
            centerTranslation.columns.3 = simd_float4(centerOffset.x, centerOffset.y, centerOffset.z, 1)
            transform = transform * centerTranslation
            
            return transform
        }
        
        private func makeRotationMatrixX(angle: Float) -> simd_float4x4 {
            let c = cos(angle)
            let s = sin(angle)
            return simd_float4x4(
                simd_float4(1, 0, 0, 0),
                simd_float4(0, c, s, 0),
                simd_float4(0, -s, c, 0),
                simd_float4(0, 0, 0, 1)
            )
        }
        
        private func makeRotationMatrixY(angle: Float) -> simd_float4x4 {
            let c = cos(angle)
            let s = sin(angle)
            return simd_float4x4(
                simd_float4(c, 0, -s, 0),
                simd_float4(0, 1, 0, 0),
                simd_float4(s, 0, c, 0),
                simd_float4(0, 0, 0, 1)
            )
        }
        
        private func makeRotationMatrixZ(angle: Float) -> simd_float4x4 {
            let c = cos(angle)
            let s = sin(angle)
            return simd_float4x4(
                simd_float4(c, s, 0, 0),
                simd_float4(-s, c, 0, 0),
                simd_float4(0, 0, 1, 0),
                simd_float4(0, 0, 0, 1)
            )
        }
        
        private func makePerspectiveMatrix(fovRadians: Float, aspect: Float, nearZ: Float, farZ: Float) -> simd_float4x4 {
            let ys = 1 / tanf(fovRadians * 0.5)
            let xs = ys / aspect
            let zs = farZ / (nearZ - farZ)
            
            return simd_float4x4(
                simd_float4(xs, 0, 0, 0),
                simd_float4(0, ys, 0, 0),
                simd_float4(0, 0, zs, -1),
                simd_float4(0, 0, nearZ * zs, 0)
            )
        }
        
        private func makeLookAtMatrix(eye: SIMD3<Float>, target: SIMD3<Float>, up: SIMD3<Float>) -> simd_float4x4 {
            let z = normalize(eye - target)
            let x = normalize(cross(up, z))
            let y = cross(z, x)
            
            return simd_float4x4(
                simd_float4(x.x, y.x, z.x, 0),
                simd_float4(x.y, y.y, z.y, 0),
                simd_float4(x.z, y.z, z.z, 0),
                simd_float4(-dot(x, eye), -dot(y, eye), -dot(z, eye), 1)
            )
        }
    }
}
#endif

#if os(macOS)
import AppKit

struct MetalKitView: NSViewRepresentable {
    @Binding var renderer: SplatRenderer?
    var cameraPosition: SIMD3<Float> = SIMD3<Float>(0, 0.5, 2.0)
    var centerOffset: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    var baseRotation: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    var modelRotation: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    var modelPosition: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    var modelScale: Float = 1.0
    @Binding var gestureRotationX: Float
    @Binding var gestureRotationY: Float
    @Binding var zoomScale: Float
    @Binding var cameraOrbitX: Float
    @Binding var cameraOrbitY: Float
    var onMVPMatrix: ((simd_float4x4, CGSize) -> Void)?
    
    func makeNSView(context: Context) -> MTKView {
        let metalView = MTKView()
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        
        metalView.device = device
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.depthStencilPixelFormat = .depth32Float
        metalView.sampleCount = 1
        
        // Initialize SplatRenderer with required parameters
        do {
            let splatRenderer = try SplatRenderer(
                device: device,
                colorFormat: metalView.colorPixelFormat,
                depthFormat: metalView.depthStencilPixelFormat,
                sampleCount: metalView.sampleCount,
                maxViewCount: 1,
                maxSimultaneousRenders: 1
            )
            
            metalView.delegate = context.coordinator
            context.coordinator.renderer = splatRenderer
            DispatchQueue.main.async {
                renderer = splatRenderer
            }
        } catch {
            print("Failed to initialize SplatRenderer: \(error)")
        }
        
        return metalView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        var renderer: SplatRenderer?
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Handle drawable size changes
        }
        
        func draw(in view: MTKView) {
            // Rendering disabled until MetalSplatter API is confirmed
        }
    }
}
#endif

#Preview {
    ContentView()
}
