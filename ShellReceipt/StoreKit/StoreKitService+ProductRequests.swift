//
//  StoreKitService+ProductRequests.swift
//  ShellReceipt
//
//  Created by Pongt Chia on 1/11/25.
//

import Foundation
import StoreKit

/// SKProductsRequestDelegate forwarded from StoreKit callbacks.
extension StoreKitService: SKProductsRequestDelegate {
    nonisolated func productsRequest(
        _ request: SKProductsRequest,
        didReceive response: SKProductsResponse
    ) {
        DispatchQueue.main.async {
            self.products = response.products.sorted {
                $0.productIdentifier < $1.productIdentifier
            }
            if response.invalidProductIdentifiers.isEmpty == false {
                print(
                    "[StoreKit] Invalid product IDs: \(response.invalidProductIdentifiers)"
                )
            }
        }
    }

    nonisolated func request(
        _ request: SKRequest,
        didFailWithError error: Error
    ) {
        DispatchQueue.main.async {
            print("[StoreKit] Request failed: \(error.localizedDescription)")
        }
    }
}
