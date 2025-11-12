//
//  ProductCatalog.Test.swift
//  ShellReceipt
//
//  Created by Pongt Chia on 1/12/25.
//

import Foundation

struct TestProductCatalog: ProductCatalogProvider {
    let appleSharedSecret = "1234567890"

    let consumableProducts: Set<String> = [
        "com.example.consumable.coffee"
    ]

    let subscriptionProducts: Set<String> = [
        "com.example.premium.monthly",
        "com.example.premium.yearly",
    ]
}
