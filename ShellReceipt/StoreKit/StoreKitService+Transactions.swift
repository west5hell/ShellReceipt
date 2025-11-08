//
//  StoreKitService+Transactions.swift
//  ShellReceipt
//
//  Created by Pongt Chia on 1/11/25.
//

import os.log
import StoreKit

/// Transaction observer forwarding StoreKit callbacks to the main actor.
extension StoreKitService: SKPaymentTransactionObserver {
    nonisolated func paymentQueue(
        _ queue: SKPaymentQueue,
        updatedTransactions transactions: [SKPaymentTransaction]
    ) {
        transactions.forEach { transaction in
            DispatchQueue.main.async {
                self.handle(transaction: transaction)
            }
        }
    }

    nonisolated func paymentQueueRestoreCompletedTransactionsFinished(
        _ queue: SKPaymentQueue
    ) {
        DispatchQueue.main.async {
            StoreKitLogger.general.info("Restore completed.")
            self.isRestoring = false
            Task {
                try? await self.validateWithApple(
                    sharedSecret: ProductCatalog.appleSharedSecret,
                    productID: nil
                )
            }
        }
    }

    nonisolated func paymentQueue(
        _ queue: SKPaymentQueue,
        restoreCompletedTransactionsFailedWithError error: Error
    ) {
        DispatchQueue.main.async {
            StoreKitLogger.general.error(
                "Restore failed: \(error.localizedDescription, privacy: .public)"
            )
            self.isRestoring = false
        }
    }

    /// Keep the published state in sync with StoreKit transaction updates.
    private func handle(transaction: SKPaymentTransaction) {
        let productID = transaction.payment.productIdentifier

        switch transaction.transactionState {
        case .purchased:
            purchasedProductIDs.insert(productID)
            StoreKitLogger.general.info(
                "Purchase success: \(productID, privacy: .public)"
            )
            isPurchasing = false
            SKPaymentQueue.default().finishTransaction(transaction)
            Task {
                try? await self.validateWithApple(
                    sharedSecret: ProductCatalog.appleSharedSecret,
                    productID: productID
                )
            }
        case .restored:
            purchasedProductIDs.insert(productID)
            if restoredLogIdentifiers.insert(productID).inserted {
                StoreKitLogger.general.info(
                    "Purchase restored: \(productID, privacy: .public)"
                )
            }
            isPurchasing = false
            SKPaymentQueue.default().finishTransaction(transaction)
        case .failed:
            if let error = transaction.error as? SKError,
                error.code != .paymentCancelled
            {
                StoreKitLogger.general.error(
                    "Purchase failed: \(error.localizedDescription, privacy: .public)"
                )
            } else {
                StoreKitLogger.general.info("Purchase cancelled.")
            }
            isPurchasing = false
            SKPaymentQueue.default().finishTransaction(transaction)
        case .deferred:
            StoreKitLogger.general.info(
                "Purchase deferred: \(productID, privacy: .public)"
            )
            isPurchasing = false
        case .purchasing:
            break
        @unknown default:
            StoreKitLogger.general.error("Unknown transaction state.")
            SKPaymentQueue.default().finishTransaction(transaction)
        }
    }
}
