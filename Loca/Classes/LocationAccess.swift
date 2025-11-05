//
//  LocationAccess.swift
//  Loca
//
//  Created by Jarrod Norwell on 29/10/2025.
//

import CoreLocation

class LocationAccess : NSObject {
    var authorised: Bool = false
    var status: CLAuthorizationStatus = .notDetermined
    
    var manager: CLLocationManager = .init()
    
    func checkAuthorisationStatus() {
        status = manager.authorizationStatus
        authorised = status == .authorizedAlways || status == .authorizedWhenInUse
    }
    
    func authorise() {
        manager.requestAlwaysAuthorization()
        authorised = manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse
    }
}
