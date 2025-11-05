//
//  Location.swift
//  Loca
//
//  Created by Jarrod Norwell on 1/11/2025.
//

import CoreLocation

nonisolated struct Location : Codable, Hashable {
    nonisolated struct Heading : Codable, Hashable {
        var magneticHeading: CLLocationDirection = 0,
            trueHeading: CLLocationDirection = 0,
            headingAccuracy: CLLocationDirection = 0

        var x: CLHeadingComponentValue = 0,
            y: CLHeadingComponentValue = 0,
            z: CLHeadingComponentValue = 0

        var timestamp: Date = .now
    }
    
    nonisolated struct Speed : Codable, Hashable {
        var speed: CLLocationSpeed = 0
        var speedAccuracy: CLLocationSpeedAccuracy = 0
    }
    
    nonisolated struct Weather : Codable, Hashable {
        var day: Bool = false
        var symbolName: String = ""
        var temperature: Measurement<UnitTemperature> = .init(value: 0, unit: .celsius)
    }
    
    var heading: Heading
    var latitude: CLLocationDegrees,
        longitude: CLLocationDegrees
    var speed: Speed
    var weather: Weather
    
    var coordinate: CLLocationCoordinate2D {
        location.coordinate
    }
    
    var location: CLLocation {
        .init(latitude: latitude, longitude: longitude)
    }
}
