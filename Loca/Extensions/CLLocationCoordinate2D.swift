//
//  CLLocationCoordinate2D.swift
//  Loca
//
//  Created by Jarrod Norwell on 31/10/2025.
//

import CoreLocation
import Foundation

nonisolated extension CLLocationCoordinate2D {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
    
    func bearing(to destination: Self) -> CLLocationDirection {
        let lat1 = latitude.radians
        let lon1 = longitude.radians
        
        let lat2 = destination.latitude.radians
        let lon2 = destination.longitude.radians
        
        let dLon = lon2 - lon1
        
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let y = sin(dLon) * cos(lat2)
        
        var degreesBearing = atan2(y, x).degrees
        if degreesBearing < 0 {
            degreesBearing += 360
        }
        return degreesBearing
    }
    
    func cardinal(from bearing: CLLocationDirection) -> String {
        switch bearing.normalizedDegrees {
        case 0..<22.5,
            337.5..<360: "North"
        case 22.5..<67.5: "North East"
        case 67.5..<112.5: "East"
        case 112.5..<157.5: "South East"
        case 157.5..<202.5: "South"
        case 202.5..<247.5: "South West"
        case 247.5..<292.5: "West"
        case 292.5..<337.5: "North West"
        default: "North"
        }
    }
}
