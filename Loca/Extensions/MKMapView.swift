//
//  MKMapView.swift
//  Loca
//
//  Created by Jarrod Norwell on 29/10/2025.
//

import MapKit

extension MKMapView {
    func addAnnotations(for friends: [Friend]) {
        for friend in friends {
            if annotations.contains(where: { $0.subtitle == friend.id }) {
                let annotation = annotations.first(where: { $0.subtitle == friend.id })
                if let annotation = annotation as? DynamicAnnotation {
                    UIView.animate(withDuration: 1 / 3) {
                        annotation.coordinate = friend.location.coordinate
                    }
                }
            } else {
                let pointAnnotation: DynamicAnnotation = .init(coordinate: .init(latitude: friend.location.latitude,
                                                                                 longitude: friend.location.longitude),
                                                               title: friend.name.formatted(),
                                                               subtitle: friend.id)
                
                addAnnotation(pointAnnotation)
            }
        }
    }
}
