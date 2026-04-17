//
//  Statue+Annotations.swift
//  Sansarana
//
//  Curated annotation data for each statue at Gal Viharaya.
//

import Foundation
import simd

extension Statue {
    
    var annotations: [Annotation] {
        switch self {
        case .seatedBuddha:
            return [
                Annotation(
                    id: UUID(),
                    title: "Makara Torana",
                    subtitle: "Mythical arch",
                    position3D: SIMD3<Float>(0, 0.8, 0),
                    content: AnnotationContent(
                        title: "Makara Torana",
                        description: "Behind the head of the Buddha is a bas-relief of a halo. The entire figure is framed by a relief in the shape of an arch, which is called Prabhamandala in Indian art. It resembles a Torana, a wooden gate, which is richly ornamented. Heads of the mythical crocodile-dragons called Makaras can be seen projecting on either side, holding small lions in their mouths. The upper part of the arch carries small celestial palaces or shrines with bas reliefs depicting Buddhas in their front niches or entrances.",
                        facts: [
                            "Intricate carvings depicting Makaras",
                            "Symbolizes the threshold between worldly and spiritual realms",
                            "Common motif in Sri Lankan Buddhist architecture"
                        ],
                        images: []
                    )
                ),
                Annotation(
                    id: UUID(),
                    title: "Dhyana Mudra",
                    subtitle: "Meditative gesture",
                    position3D: SIMD3<Float>(0.3, 0.4, 0.2),
                    content: AnnotationContent(
                        title: "Dhyana Mudra",
                        description: "The seated sculpture is depicted in the common meditation gesture, which is called Samadhi Mudra or Dhyani Mudra, both hands are placed on the lap, right hand on left with fingers fully stretched.",
                        facts: [
                            "Represents concentration and contemplation",
                            "Associated with Buddha's meditation under the Bodhi tree",
                            "Symbolizes the path to enlightenment"
                        ],
                        images: []
                    )
                ),
                Annotation(
                    id: UUID(),
                    title: "Lion Pedestal",
                    subtitle: "Royal foundation",
                    position3D: SIMD3<Float>(-0.3, -0.5, 0),
                    content: AnnotationContent(
                        title: "Lion Pedestal",
                        description: "The imposing rock-cut figure sits on a throne, an Asana, the front of which is decorated with lions and thunderbolt symbols.",
                        facts: [
                            "Lions represent the Buddha's royal heritage",
                            "The pedestal elevates the figure spiritually",
                            "Carved from a single piece of granite"
                        ],
                        images: []
                    )
                ),
                Annotation(
                    id: UUID(),
                    title: "Granite Gneiss",
                    subtitle: "Monolithic rock",
                    position3D: SIMD3<Float>(0, -0.7, -0.2),
                    content: AnnotationContent(
                        title: "Granite Gneiss",
                        description: "The entire statue is carved from a single piece of granite gneiss, a metamorphic rock native to the region.",
                        facts: [
                            "Highly durable stone, lasting over 800 years",
                            "Natural striations visible in the rock",
                            "Required exceptional skill to carve"
                        ],
                        images: []
                    )
                )
            ]
        case .standingBuddha:
            return [
                Annotation(
                    id: UUID(),
                    title: "Crossed Arms",
                    subtitle: "Unique posture",
                    position3D: SIMD3<Float>(0, 0.5, 0.2),
                    content: AnnotationContent(
                        title: "Crossed Arms Posture",
                        description: "This unique posture with crossed arms is rare in Buddhist sculpture and has been subject to various interpretations.",
                        facts: [
                            "Some scholars believe it represents Ananda, Buddha's disciple",
                            "Others interpret it as Buddha in contemplation",
                            "The posture conveys serenity and introspection"
                        ],
                        images: []
                    )
                ),
                Annotation(
                    id: UUID(),
                    title: "Padmasana",
                    subtitle: "Pedestal",
                    position3D: SIMD3<Float>(0, 0.5, 0.2),
                    content: AnnotationContent(
                        title: "Crossed Arms Posture",
                        description: "In Buddhist iconography, the Padmasana, a pedestal in the form of a lotus throne, is usually reserved for Buddha statues.",
                        facts: [],
                        images: []
                    )
                )
            ]
        case .recliningBuddha:
            return [
                Annotation(
                    id: UUID(),
                    title: "Parinirvana",
                    subtitle: "Final liberation",
                    position3D: SIMD3<Float>(0, 0.3, 0),
                    content: AnnotationContent(
                        title: "Parinirvana",
                        description: "The reclining posture depicts the Buddha's final moments before entering Parinirvana, the ultimate state of liberation.",
                        facts: [
                            "14 meters (46 feet) in length",
                            "The peaceful expression represents transcendence",
                            "One of the finest reclining Buddha sculptures in Sri Lanka"
                        ],
                        images: []
                    )
                ),
                Annotation(
                    id: UUID(),
                    title: "Cylindrical pillow",
                    subtitle: "Pillow",
                    position3D: SIMD3<Float>(0, 0.3, 0),
                    content: AnnotationContent(
                        title: "Cylindrical pillow",
                        description: "The Buddha rests his head on an elaborately decorated cylindrical pillow, the carving of which is carefully executed. It has a slight depression under the weight of the head. The pillow is decorated with the Chakra, the eternal wheel. The very centre of the pillow shows a so-called \"Lion-Face\" (Kirthimukha).",
                        facts: [],
                        images: []
                    )
                )
            ]
        }
    }
}
