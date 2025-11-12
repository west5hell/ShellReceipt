//
//  ProductCatalog.Review.swift
//  ShellReceipt
//
//  Created by Pongt Chia on 1/12/25.
//

import Foundation

struct ReviewProductCatalog: ProductCatalogProvider {
    let appleSharedSecret = "<#Production Shared Secret#>"

    let consumableProducts: Set<String> = [
        "<#production.consumable#>"
    ]

    let subscriptionProducts: Set<String> = [
        "<#production.subscription.monthly#>",
        "<#production.subscription.yearly#>",
    ]
}
