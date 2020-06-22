//
// Copyright © 2019 Apple Inc., IZE Ltd. and the project authors
// Licensed under MIT License
//
// See LICENSE.txt for license information.
//

import Foundation
import CryptoKit
import TCNClient

/// The interface needed for SecKey conversion.
public protocol GenericPasswordConvertible: CustomStringConvertible {
    /// Creates a key from a raw representation.
    init<D>(rawRepresentation data: D) throws where D: ContiguousBytes
    
    /// Creates a new key.
    init() throws
    
    /// A raw representation of the key.
    var rawRepresentation: Data { get }
}

extension GenericPasswordConvertible {
    /// A string version of the key for visual inspection.
    /// IMPORTANT: Never log the actual key data.
    public var description: String {
        return self.rawRepresentation.withUnsafeBytes { bytes in
            return "Key representation contains \(bytes.count) bytes."
        }
    }
}

// Declare that the Curve25519 keys are generic passord convertible.
@available(iOS 13.0, *)
extension Curve25519.KeyAgreement.PrivateKey: GenericPasswordConvertible {}
@available(iOS 13.0, *)
extension Curve25519.Signing.PrivateKey: GenericPasswordConvertible {}

extension Curve25519PrivateKey: GenericPasswordConvertible {}
extension String: GenericPasswordConvertible {
    public var rawRepresentation: Data {
        return self.data(using: .utf8) ?? Data()
    }
    
    public init<D>(rawRepresentation data: D) throws where D: ContiguousBytes {
        self.init(data: data as! Data, encoding: .utf8)!
    }
}

// Ensure that Secure Enclave keys are generic password convertible.
//@available(iOS 13.0, *)
//extension SecureEnclave.P256.KeyAgreement.PrivateKey: GenericPasswordConvertible {
//
//    @available(iOS 13.0, *)
//    public init<D>(rawRepresentation data: D) throws where D: ContiguousBytes {
//        try self.init(dataRepresentation: data.dataRepresentation)
//    }
//
//    @available(iOS 13.0, *)
//    public init() throws {
//        try self.init(
//            compactRepresentable: true,
//            accessControl: SecAccessControlCreateWithFlags(
//                nil,
//                kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
//                [.privateKeyUsage],
//                nil
//                )!,
//            authenticationContext: nil
//        )
//    }
//
//    public var rawRepresentation: Data {
//        // Contiguous bytes repackaged as a Data instance.
//        return dataRepresentation
//    }
//}

//@available(iOS 13.0, *)
//extension SecureEnclave.P256.Signing.PrivateKey: GenericPasswordConvertible {
//    
//    @available(iOS 13.0, *)
//    public init<D>(rawRepresentation data: D) throws where D: ContiguousBytes {
//        try self.init(dataRepresentation: data.dataRepresentation)
//    }
//    
//    @available(iOS 13.0, *)
//    public init() throws {
//        try self.init(
//            compactRepresentable: true,
//            accessControl: SecAccessControlCreateWithFlags(
//                nil,
//                kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
//                [.privateKeyUsage],
//                nil
//                )!,
//            authenticationContext: nil
//        )
//    }
//    
//    public var rawRepresentation: Data {
//        return dataRepresentation // Contiguous bytes repackaged as a Data instance.
//    }
//}

extension ContiguousBytes {
    /// A Data instance created safely from the contiguous bytes without making any copies.
    var dataRepresentation: Data {
        return self.withUnsafeBytes { bytes in
            let cfdata = CFDataCreateWithBytesNoCopy(
                nil,
                bytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                bytes.count,
                kCFAllocatorNull
            )
            return ((cfdata as NSData?) as Data?) ?? Data()
        }
    }
}
