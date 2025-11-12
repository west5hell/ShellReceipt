//
//  ReceiptModels.swift
//  ShellReceipt
//
//  Created by Pongt Chia on 1/11/25.
//

import Foundation
import StoreKit

/// Encapsulates the data required for remote receipt verification.
struct ReceiptPayload {
    let base64Receipt: String
    let productID: String?
}

enum ReceiptError: Error {
    case missing
    case empty
}

extension SKProduct {
    var identifiableID: String { productIdentifier }
}
