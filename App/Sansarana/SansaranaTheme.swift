//
//  SansaranaTheme.swift
//  Sansarana
//
//  Brand colours, gradients, typography, and spacing constants.
//

import SwiftUI

// MARK: - Brand Colours
extension Color {
    /// Warm saffron gold — primary accent
    static let saffronGold = Color(red: 0.96, green: 0.75, blue: 0.16)
    /// Deep heritage brown — secondary accent
    static let heritageBrown = Color(red: 0.36, green: 0.22, blue: 0.09)
    /// Soft temple cream — backgrounds
    static let templeCream = Color(red: 0.98, green: 0.95, blue: 0.88)
    /// Lotus pink — highlights
    static let lotusPink = Color(red: 0.91, green: 0.45, blue: 0.56)
    /// Deep midnight — dark backgrounds
    static let midnightBlue = Color(red: 0.07, green: 0.09, blue: 0.18)
}

// MARK: - Gradients
extension LinearGradient {
    static let saffronGradient = LinearGradient(
        colors: [.saffronGold, .saffronGold.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let heritageGradient = LinearGradient(
        colors: [.heritageBrown, .heritageBrown.opacity(0.8)],
        startPoint: .top,
        endPoint: .bottom
    )
}
