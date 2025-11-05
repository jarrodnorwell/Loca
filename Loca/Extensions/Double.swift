//
//  Double.swift
//  Loca
//
//  Created by Jarrod Norwell on 1/11/2025.
//

import Foundation

nonisolated extension Double {
    var degrees: Self {
        self * 180 / .pi
    }
    
    var normalizedDegrees: Self {
        var angle = truncatingRemainder(dividingBy: 360)
        if angle < 0 {
            angle += 360
        }
        return angle
    }
    
    var radians: Self {
        self * .pi / 180
    }
}
