//
//  ProductIdentifiers.swift
//  ShellReceipt
//
//  Created by Pongt Chia on 1/11/25.
//

import Foundation

let appleSharedSecret = "<Apple Shared Secret>"

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

let consumableProductIDs: Set<String> = [
    "com.example.consumable.coffee"
]

let subscriptionProductIDs: Set<String> = [
    "com.example.premium.monthly",
    "com.example.premium.yearly",
]
