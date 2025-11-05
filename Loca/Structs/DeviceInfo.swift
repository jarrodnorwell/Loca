//
//  DeviceInfo.swift
//  Loca
//
//  Created by Jarrod Norwell on 1/11/2025.
//

nonisolated struct DeviceInfo : Codable, Hashable {
    var batteryLevel: Float = 0
    var batteryState: Int = 0
    var lowPowerMode: Bool = false
}
