//
//  Statue+SplatConfig.swift
//  Sansarana
//
//  Per-statue 3D Gaussian Splat viewer configuration (camera, rotation, scale).
//

import simd

extension Statue {
    
    var splatFileName: String {
        switch self {
        case .seatedBuddha: "cleaned_seated_statue.ply"
        case .standingBuddha: "cleaned_standing_statue.ply"
        case .recliningBuddha: "cleaned_reclining_statue.ply"
        }
    }
    
    var defaultCenterOffset: SIMD3<Float> {
        switch self {
        case .seatedBuddha: SIMD3<Float>(-0.005, -0.855, 0.176)
        case .standingBuddha: SIMD3<Float>(0, 0, 0)
        case .recliningBuddha: SIMD3<Float>(0, 0, 0)
        }
    }
    
    var defaultBaseRotation: SIMD3<Float> {
        switch self {
        case .seatedBuddha: SIMD3<Float>(.pi, 0, 0)
        case .standingBuddha: SIMD3<Float>(0, .pi, 0)
        case .recliningBuddha: SIMD3<Float>(0.1, .pi / 2, 0)
        }
    }
    
    var defaultCameraPosition: SIMD3<Float> {
        switch self {
        case .seatedBuddha: SIMD3<Float>(0, 0, 1.0)
        case .standingBuddha: SIMD3<Float>(0, 0.5, 4.0)
        case .recliningBuddha: SIMD3<Float>(0, 0.5, 5.0)
        }
    }
    
    var defaultScale: Float {
        switch self {
        case .seatedBuddha: 1.0
        case .standingBuddha: 1.0
        case .recliningBuddha: 0.8
        }
    }
    
    var defaultModelRotation: SIMD3<Float> {
        SIMD3<Float>(0, 0, 0)
    }
    
    var defaultModelPosition: SIMD3<Float> {
        SIMD3<Float>(0, 0, 0)
    }
    
    var defaultZoomScale: Float { 1.0 }
    
    var defaultCameraOrbit: SIMD2<Float> {
        SIMD2<Float>(0, 0)
    }
    
    var defaultGestureRotation: SIMD2<Float> {
        SIMD2<Float>(0, 0)
    }
}
