//
//  StoreKitService+Transactions.swift
//  ShellReceipt
//
//  Created by Pongt Chia on 1/11/25.
//

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
            print("[StoreKit] Restore completed.")
            self.isRestoring = false
        }
    }

    nonisolated func paymentQueue(
        _ queue: SKPaymentQueue,
        restoreCompletedTransactionsFailedWithError error: Error
    ) {
        DispatchQueue.main.async {
            print("[StoreKit] Restore failed: \(error.localizedDescription)")
            self.isRestoring = false
        }
    }

    /// Keep the published state in sync with StoreKit transaction updates.
    private func handle(transaction: SKPaymentTransaction) {
        let productID = transaction.payment.productIdentifier

        switch transaction.transactionState {
        case .purchased:
            purchasedProductIDs.insert(productID)
            print("[StoreKit] Purchase success: \(productID)")
            isPurchasing = false
            SKPaymentQueue.default().finishTransaction(transaction)
            Task {
                try? await self.validateWithApple(
                    sharedSecret: nil,
                    productID: productID
                )
            }
        case .restored:
            purchasedProductIDs.insert(productID)
            print("[StoreKit] Purchase restored: \(productID)")
            isPurchasing = false
            SKPaymentQueue.default().finishTransaction(transaction)
            Task {
                try? await self.validateWithApple(
                    sharedSecret: nil,
                    productID: productID
                )
            }
        case .failed:
            if let error = transaction.error as? SKError,
                error.code != .paymentCancelled
            {
                print(
                    "[StoreKit] Purchase failed: \(error.localizedDescription)"
                )
            } else {
                print("[StoreKit] Purchase cancelled.")
            }
            isPurchasing = false
            SKPaymentQueue.default().finishTransaction(transaction)
        case .deferred:
            print("[StoreKit] Purchase deferred: \(productID)")
            isPurchasing = false
        case .purchasing:
            break
        @unknown default:
            print("[StoreKit] Unknown transaction state.")
            SKPaymentQueue.default().finishTransaction(transaction)
        }
    }
}
