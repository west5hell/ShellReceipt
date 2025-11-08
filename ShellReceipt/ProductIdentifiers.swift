//
//  ProductIdentifiers.swift
//  ShellReceipt
//
//  Created by Pongt Chia on 1/11/25.
//

import Foundation

enum ProductCatalog {
    static let appleSharedSecret = "<Apple Shared Secret>"

    /// Consumable products surfaced in `ConsumableProductsView`.
    static let consumableProducts: Set<String> = [
        "com.example.consumable.coffee"
    ]

    /// Subscription identifiers used across the app and validation layer.
    static let subscriptionProducts: Set<String> = [
        "com.example.premium.monthly",
        "com.example.premium.yearly",
    ]

    /// Convenience union for initializing StoreKit product requests.
    static let allProducts: Set<String> = consumableProducts.union(
        subscriptionProducts
    )
}

enum ValidationChoice: String, CaseIterable, Identifiable {
    case apple
    case server

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apple: return "Apple"
        case .server: return "服务器"
        }
    }
}
