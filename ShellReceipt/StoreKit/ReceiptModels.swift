//
//  ReceiptModels.swift
//  ShellReceipt
//
//  Created by Pongt Chia on 1/11/25.
//

import Foundation
import StoreKit

/// Describes how receipts should be verified.
enum ReceiptValidationMode {
    /// Hand the receipt to Apple for official validation.
    case apple(sharedSecret: String?)
    /// Skip Apple and return the raw receipt for a custom server.
    case customServer
}

/// Encapsulates the data required for remote receipt verification.
struct ReceiptPayload {
    let base64Receipt: String
    let productID: String?
}

/// Outcome of a receipt verification attempt.
struct ReceiptValidationResult {
    let activeSubscriptions: Set<String>
    let environment: ReceiptEnvironment
    let rawBody: [String: Any]
}

/// Apple verification endpoints.
enum ReceiptEnvironment {
    case production
    case sandbox

    var url: URL {
        switch self {
        case .production:
            return URL(string: "https://buy.itunes.apple.com/verifyReceipt")!
        case .sandbox:
            return URL(
                string: "https://sandbox.itunes.apple.com/verifyReceipt"
            )!
        }
    }

    var description: String {
        switch self {
        case .production:
            return "production"
        case .sandbox:
            return "sandbox"
        }
    }

    init(string: String) {
        switch string.lowercased() {
        case "sandbox":
            self = .sandbox
        default:
            self = .production
        }
    }
}

protocol ReceiptValidating {
    func validate(receiptData: Data, productID: String?) async throws
        -> ReceiptValidationResult
}

enum ReceiptError: Error {
    case missing
    case empty
}

extension SKProduct {
    var identifiableID: String { productIdentifier }
}
