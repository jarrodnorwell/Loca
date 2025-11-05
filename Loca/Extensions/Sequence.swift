//
//  Sequence.swift
//  Loca
//
//  Created by Jarrod Norwell on 29/10/2025.
//

import Foundation

extension Sequence {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var values: [T] = .init()

        for element in self {
            try await values.append(transform(element))
        }

        return values
    }
}
