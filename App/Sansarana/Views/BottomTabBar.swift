//
//  BottomTabBar.swift
//  Sansarana
//
//  Created by Chulan Shammi on 2026-03-18.
//

import SwiftUI

struct BottomTabBar: View {
    @Binding var selectedTab: AppTab
    var isStatueDetected: Bool = false
    
    var body: some View {
        HStack(spacing: 0) {
            TabButton(
                title: "Chat",
                icon: "bubble.left.and.bubble.right.fill",
                isSelected: selectedTab == .chat,
                isEnabled: isStatueDetected
            ) {
                selectedTab = .chat
            }
            
            Divider()
                .frame(height: 30)
                .background(.white.opacity(0.3))
            
            TabButton(
                title: "History",
                icon: "clock.fill",
                isSelected: selectedTab == .history,
                isEnabled: true
            ) {
                selectedTab = .history
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 20)
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    var isEnabled: Bool = true
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                
                Text(title)
                    .font(.headline)
            }
            .foregroundStyle(isEnabled ? (isSelected ? .white : .white.opacity(0.7)) : .white.opacity(0.3))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .disabled(!isEnabled)
    }
}

#Preview {
    ZStack {
        Color.blue.ignoresSafeArea()
        
        VStack {
            Spacer()
            BottomTabBar(selectedTab: .constant(.ar), isStatueDetected: true)
        }
    }
}
