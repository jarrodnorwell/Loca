//
//  String.swift
//  Loca
//
//  Created by Jarrod Norwell on 29/10/2025.
//

import CryptoKit
import Foundation

extension String {
    static func nonce(with length: Int = 32) -> Self {
        precondition(length > 0)
        
        var bytes: [UInt8] = .init(repeating: 0, count: length)
        let errorCode: Int32 = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = .init("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        
        let nonce = bytes.map { byte in charset[Int(byte) % charset.count] }
        return .init(nonce)
    }
    
    static func sha256(from input: String) -> Self {
        let data: Data = .init(input.utf8)
        let hash: SHA256Digest = SHA256.hash(data: data)
        return hash.map { number in .init(format: "%02x", number) }.joined()
    }
}
