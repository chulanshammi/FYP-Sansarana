//
//  HistoryView.swift
//  Sansarana
//
//  Created by Chulan Shammi on 2026-03-18.
//

import SwiftUI

// MARK: - History View

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = VisitHistoryViewModel()
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.visits.isEmpty {
                    EmptyHistoryView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.visits) { visit in
                                PlaceVisitCard(visit: visit)
                                    .onTapGesture {
                                        viewModel.selectedVisit = visit
                                    }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $viewModel.selectedVisit) { visit in
                PlaceArtifactsView(visit: visit)
            }
            .task {
                viewModel.loadVisits()
            }
        }
    }
}

// MARK: - Empty State

struct EmptyHistoryView: View {
    var body: some View {
        ContentUnavailableView(
            "No Visit History",
            systemImage: "clock",
            description: Text("Your visits to the Gal Viharaya statues will appear here.")
        )
    }
}

// MARK: - Place Visit Card

struct PlaceVisitCard: View {
    let visit: PlaceVisit
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: visit.visitDate)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(visit.placeName)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.caption)
                        Text(visit.location)
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if visit.verified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
            }
            
            Divider()
            
            HStack(spacing: 20) {
                // Artifact count
                HStack(spacing: 6) {
                    Image(systemName: "cube.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                    Text("\(visit.artifactCount) Artifact\(visit.artifactCount == 1 ? "" : "s")")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                // Visit date
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                    Text(formattedDate)
                        .font(.subheadline)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        }
    }
}

// MARK: - Place Artifacts View (shown when a place card is tapped)

struct PlaceArtifactsView: View {
    let visit: PlaceVisit
    @Environment(\.dismiss) private var dismiss
    @State private var selectedStatue: Statue?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Place header
                    VStack(spacing: 8) {
                        Text(visit.placeName)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.caption)
                            Text(visit.location)
                                .font(.subheadline)
                        }
                        .foregroundStyle(.secondary)
                        
                        let formatter = DateFormatter()
                        let _ = formatter.dateStyle = .long
                        Text("Visited \(formatter.string(from: visit.visitDate))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, 8)
                    
                    // Artifacts grid
                    LazyVStack(spacing: 16) {
                        ForEach(Statue.allCases, id: \.rawValue) { statue in
                            ArtifactCard(
                                statue: statue,
                                wasSeen: visit.artifactsSeen.contains(statue)
                            )
                            .onTapGesture {
                                selectedStatue = statue
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .navigationTitle("Artifacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedStatue) { statue in
                DetailView(
                    statue: statue,
                    annotation: statue.annotations.first!
                )
            }
        }
    }
}

// MARK: - Artifact Card

struct ArtifactCard: View {
    let statue: Statue
    let wasSeen: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 56, height: 56)
                
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundStyle(wasSeen ? .white : .gray)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(statue.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(statue.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text(statue.height)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                if wasSeen {
                    Image(systemName: "eye.fill")
                        .foregroundStyle(.green)
                    Text("Viewed")
                        .font(.caption2)
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "eye.slash")
                        .foregroundStyle(.gray)
                    Text("Not seen")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
        }
    }
    
    private var iconBackgroundColor: Color {
        if !wasSeen { return .gray.opacity(0.3) }
        switch statue {
        case .seatedBuddha: return .orange
        case .standingBuddha: return .blue
        case .recliningBuddha: return .purple
        }
    }
    
    private var iconName: String {
        switch statue {
        case .seatedBuddha: return "figure.seated.seatbelt"
        case .standingBuddha: return "figure.stand"
        case .recliningBuddha: return "figure.cooldown"
        }
    }
}

#Preview {
    HistoryView()
}
