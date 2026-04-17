//
//  VisitHistoryViewModel.swift
//  Sansarana
//
//  ViewModel for managing visit history display and persistence.
//

import SwiftUI
import Combine

@MainActor
final class VisitHistoryViewModel: ObservableObject {
    
    @Published var visits: [PlaceVisit] = []
    @Published var selectedVisit: PlaceVisit?
    
    private let service = VisitHistoryService()
    
    func loadVisits() {
        visits = service.loadVisits()
    }
    
    func recordVisit(_ visit: PlaceVisit) {
        service.saveVisit(visit)
        loadVisits()
    }
}
