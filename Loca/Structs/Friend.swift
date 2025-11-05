//
//  Friend.swift
//  Loca
//
//  Created by Jarrod Norwell on 29/10/2025.
//

import FirebaseFirestore

nonisolated final class Friend : Codable, Equatable, Hashable, Sendable {
    static func == (lhs: Friend, rhs: Friend) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
    }
    
    @DocumentID var id: String? = nil
    
    var deviceInfo: DeviceInfo
    var friends: [DocumentReference]
    var location: Location
    var name: Name
    var photoURLString: String
    
    init(id: String? = nil, deviceInfo: DeviceInfo,
         friends: [DocumentReference], location: Location,
         name: Name, photoURLString: String) {
        self.id = id
        self.deviceInfo = deviceInfo
        self.friends = friends
        self.location = location
        self.name = name
        self.photoURLString = photoURLString
    }
}

typealias Me = Friend
