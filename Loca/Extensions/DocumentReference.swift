//
//  DocumentReference.swift
//  Loca
//
//  Created by Jarrod Norwell on 3/11/2025.
//

import FirebaseFirestore

extension DocumentReference {
    func `as`<T: Decodable>(_ type: T.Type) async throws -> T {
        try await getDocument(as: type)
    }
}
