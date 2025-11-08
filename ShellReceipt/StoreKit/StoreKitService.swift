//
//  StoreKitService.swift
//  ShellReceipt
//
//  Created by Pongt Chia on 1/11/25.
//

import Combine
import Foundation
import os.log
import StoreKit

@MainActor
protocol StoreKitServiceProtocol: ObservableObject {
    var products: [SKProduct] { get }
    var purchasedProductIDs: Set<String> { get }
    var subscriptionActive: Bool { get }
    var activeSubscriptionProductIDs: Set<String> { get }
    func reloadProducts()
    func purchase(product: SKProduct)
    func restorePurchases()
    /// Validate the current receipt against Apple's endpoints, updating subscription state.
    func validateWithApple(sharedSecret: String?, productID: String?)
        async throws -> ReceiptValidationResult
    /// Return the latest receipt encoded for consumption by a custom server.
    func fetchReceiptForServer(productID: String?) async throws
        -> ReceiptPayload
}

/// Primary StoreKit 1 service providing product loading, purchase handling,
/// restore flow, and receipt utilities for Apple or custom validation paths.
@MainActor
final class StoreKitService: NSObject, StoreKitServiceProtocol {
    @Published var products: [SKProduct] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var subscriptionActive = false
    @Published var activeSubscriptionProductIDs: Set<String> = []
    @Published var isRestoring = false
    @Published var isPurchasing = false

    private let productIDs: Set<String>
    private let subscriptionProductIDs: Set<String>
    private var productsRequest: SKProductsRequest?
    var receiptRefreshDelegate: ReceiptRefreshDelegate?
    var receiptRefreshRequest: SKReceiptRefreshRequest?
    var restoredLogIdentifiers: Set<String> = []

    init(
        productIDs: Set<String>? = nil,
        subscriptionProductIDs: Set<String>? = nil
    ) {
        self.productIDs = productIDs ?? ProductCatalog.allProducts
        self.subscriptionProductIDs =
            subscriptionProductIDs ?? ProductCatalog.subscriptionProducts
        super.init()
        SKPaymentQueue.default().add(self)
    }

    deinit {
        SKPaymentQueue.default().remove(self)
    }

    /// Request the latest `SKProduct` metadata from App Store Connect.
    func reloadProducts() {
        productsRequest?.cancel()
        let request = SKProductsRequest(productIdentifiers: productIDs)
        request.delegate = self
        productsRequest = request
        request.start()
    }

    /// Initiate a payment for the specified `SKProduct`.
    func purchase(product: SKProduct) {
        guard SKPaymentQueue.canMakePayments() else {
            StoreKitLogger.general.warning("Purchases disabled on this device.")
            return
        }
        isPurchasing = true
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }

    /// Trigger StoreKit's restore flow for this queue.
    func restorePurchases() {
        isRestoring = true
        restoredLogIdentifiers.removeAll()
        SKPaymentQueue.default().restoreCompletedTransactions()
    }

    func validateWithApple(sharedSecret: String? = nil, productID: String?)
        async throws -> ReceiptValidationResult
    {
        let resolvedSecret = sharedSecret ?? ProductCatalog.appleSharedSecret
        let receiptData = try await fetchReceiptData()
        let result = try await AppleReceiptValidator(
            subscriptionProductIDs: subscriptionProductIDs,
            sharedSecret: resolvedSecret
        ).validate(receiptData: receiptData, productID: productID)
        activeSubscriptionProductIDs = result.activeSubscriptions
        subscriptionActive = !result.activeSubscriptions.isEmpty
        StoreKitLogger.general.info(
            "Apple validation finished. environment=\(result.environment.description, privacy: .public) active=\(self.subscriptionActive, privacy: .public)"
        )
        return result
    }

    func fetchReceiptForServer(productID: String?) async throws
        -> ReceiptPayload
    {
        let receiptData = try await fetchReceiptData()
        let payload = ReceiptPayload(
            base64Receipt: receiptData.base64EncodedString(),
            productID: productID
        )
        StoreKitLogger.general.info(
            "Server receipt prepared for product=\(productID ?? "unknown", privacy: .public) length=\(payload.base64Receipt.count, privacy: .public)"
        )
        return payload
    }
}
