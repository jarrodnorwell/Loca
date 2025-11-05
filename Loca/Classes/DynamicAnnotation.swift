//
//  DynamicAnnotation.swift
//  Loca
//
//  Created by Jarrod Norwell on 3/11/2025.
//

import Foundation
import MapKit

class DynamicAnnotation : NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    
    init(coordinate: CLLocationCoordinate2D, title: String? = nil, subtitle: String? = nil) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        super.init()
    }
}
