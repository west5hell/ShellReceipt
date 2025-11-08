//
//  StoreKitService+ProductRequests.swift
//  ShellReceipt
//
//  Created by Pongt Chia on 1/11/25.
//

import Foundation
import os.log
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
                let invalidIDs =
                    response.invalidProductIdentifiers.joined(separator: ", ")
                StoreKitLogger.general.warning(
                    "Invalid product IDs: \(invalidIDs, privacy: .public)"
                )
            }
        }
    }

    nonisolated func request(
        _ request: SKRequest,
        didFailWithError error: Error
    ) {
        DispatchQueue.main.async {
            StoreKitLogger.general.error(
                "Product request failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
