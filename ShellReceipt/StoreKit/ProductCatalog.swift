//
//  ProductCatalog.swift
//  ShellReceipt
//
//  Created by Pongt Chia on 1/12/25.
//

import Foundation

protocol ProductCatalogProvider {
    var appleSharedSecret: String { get }
    var consumableProducts: Set<String> { get }
    var subscriptionProducts: Set<String> { get }
}

extension ProductCatalogProvider {
    var allProducts: Set<String> { consumableProducts.union(subscriptionProducts) }
}

enum ProductCatalog {
    static var provider: ProductCatalogProvider = TestProductCatalog()

    static var appleSharedSecret: String { provider.appleSharedSecret }
    static var consumableProducts: Set<String> { provider.consumableProducts }
    static var subscriptionProducts: Set<String> { provider.subscriptionProducts }
    static var allProducts: Set<String> { provider.allProducts }
}
