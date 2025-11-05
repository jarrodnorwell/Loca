//
//  Name.swift
//  Loca
//
//  Created by Jarrod Norwell on 1/11/2025.
//

nonisolated struct Name : Codable, Hashable {
    var firstName: String,
        lastName: String
    
    func formatted() -> String {
        "\(firstName, default: "First") \(lastName, default: "Last")"
    }
}
