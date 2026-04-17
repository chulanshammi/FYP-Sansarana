//
//  VisitHistoryService.swift
//  Sansarana
//
//  Persistence layer for place visit history using UserDefaults.
//

import Foundation

struct VisitHistoryService {
    
    private let storageKey = "visitHistory"
    
    func loadVisits() -> [PlaceVisit] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([SavedVisit].self, from: data) else {
            return sampleVisits()
        }
        return saved.map { $0.toPlaceVisit() }
    }
    
    func saveVisit(_ visit: PlaceVisit) {
        var visits = loadSavedVisits()
        let saved = SavedVisit(from: visit)
        visits.append(saved)
        if let data = try? JSONEncoder().encode(visits) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    private func loadSavedVisits() -> [SavedVisit] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([SavedVisit].self, from: data) else {
            return []
        }
        return saved
    }
    
    private func sampleVisits() -> [PlaceVisit] {
        [
            PlaceVisit(
                id: UUID(),
                placeName: "Gal Viharaya",
                location: "Polonnaruwa, Sri Lanka",
                visitDate: Date().addingTimeInterval(-86400 * 2),
                artifactsSeen: [.seatedBuddha, .standingBuddha, .recliningBuddha],
                verified: true
            ),
            PlaceVisit(
                id: UUID(),
                placeName: "Gal Viharaya",
                location: "Polonnaruwa, Sri Lanka",
                visitDate: Date().addingTimeInterval(-86400 * 10),
                artifactsSeen: [.seatedBuddha, .recliningBuddha],
                verified: true
            )
        ]
    }
}

// MARK: - Codable Transport

private struct SavedVisit: Codable {
    let id: UUID
    let placeName: String
    let location: String
    let visitDate: Date
    let artifactsSeen: [String]
    let verified: Bool
    
    init(from visit: PlaceVisit) {
        self.id = visit.id
        self.placeName = visit.placeName
        self.location = visit.location
        self.visitDate = visit.visitDate
        self.artifactsSeen = visit.artifactsSeen.map(\.rawValue)
        self.verified = visit.verified
    }
    
    func toPlaceVisit() -> PlaceVisit {
        PlaceVisit(
            id: id,
            placeName: placeName,
            location: location,
            visitDate: visitDate,
            artifactsSeen: artifactsSeen.compactMap { Statue(rawValue: $0) },
            verified: verified
        )
    }
}
