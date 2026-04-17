//
//  StatueInfoCard.swift
//  Sansarana
//
//  Created by Chulan Shammi on 2026-03-18.
//

import SwiftUI

struct StatueInfoCard: View {
    let statue: Statue
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(statue.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            Text(statue.subtitle)
                .font(.headline)
                .foregroundStyle(.white.opacity(0.9))
            
            Text(statue.description)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Height:")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                    Text(statue.height)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                }
                
                if statue != .standingBuddha && statue != .recliningBuddha {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Width:")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                        Text(statue.width)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        }
        .padding(.horizontal)
    }
}

#Preview {
    ZStack {
        Color.blue.ignoresSafeArea()
        StatueInfoCard(statue: .seatedBuddha)
    }
}
