//
//  StoreKitService.swift
//  ShellReceipt
//
//  Created by Pongt Chia on 1/11/25.
//

import Combine
import Foundation
import StoreKit
import os.log

@MainActor
protocol StoreKitServiceProtocol: ObservableObject {
    var products: [SKProduct] { get }
    var purchasedProductIDs: Set<String> { get }
    var subscriptionActive: Bool { get }
    var activeSubscriptionProductIDs: Set<String> { get }
    func reloadProducts()
    func purchase(product: SKProduct)
    func restorePurchases()
    /// Return the latest receipt encoded for consumption by a custom server.
    func fetchReceiptForServer(productID: String?) async throws
        -> ReceiptPayload
    /// Submit the latest receipt to a custom validation server.
    @discardableResult
    func validateWithServer(
        networkHelper: NetworkHelper,
        productID: String?
    ) async throws -> ValidationServerResponse
}

// MARK: - Receipt utilities

extension StoreKitService {
    fileprivate func fetchReceiptData() async throws -> Data {
        let url = try receiptURL()
        if let data = try? Data(contentsOf: url), !data.isEmpty {
            return data
        }
        try await refreshReceipt()
        let refreshed = try Data(contentsOf: url)
        if refreshed.isEmpty {
            throw ReceiptError.empty
        }
        return refreshed
    }

    fileprivate func receiptURL() throws -> URL {
        guard let url = Bundle.main.appStoreReceiptURL else {
            throw ReceiptError.missing
        }
        return url
    }

    fileprivate func refreshReceipt() async throws {
        try await withCheckedThrowingContinuation { continuation in
            let request = SKReceiptRefreshRequest()
            let delegate = ReceiptRefreshDelegate { [weak self] result in
                guard let self else { return }
                self.receiptRefreshDelegate = nil
                self.receiptRefreshRequest = nil
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            receiptRefreshDelegate = delegate
            receiptRefreshRequest = request
            request.delegate = delegate
            request.start()
        }
    }
}

// MARK: - SKProductsRequestDelegate

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

// MARK: - Transaction handling

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

    private func handle(transaction: SKPaymentTransaction) {
        let productID = transaction.payment.productIdentifier

        switch transaction.transactionState {
        case .purchased:
            purchasedProductIDs.insert(productID)
            if ProductCatalog.subscriptionProducts.contains(productID) {
                activeSubscriptionProductIDs.insert(productID)
                subscriptionActive = true
            }
            StoreKitLogger.general.info(
                "Purchase success: \(productID, privacy: .public)"
            )
            isPurchasing = false
            SKPaymentQueue.default().finishTransaction(transaction)
        case .restored:
            purchasedProductIDs.insert(productID)
            if ProductCatalog.subscriptionProducts.contains(productID) {
                activeSubscriptionProductIDs.insert(productID)
                subscriptionActive = true
            }
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

// MARK: - Helpers

private final class ReceiptRefreshDelegate: NSObject, SKRequestDelegate {
    private let completion: (Result<Void, Error>) -> Void

    init(completion: @escaping (Result<Void, Error>) -> Void) {
        self.completion = completion
    }

    func requestDidFinish(_ request: SKRequest) {
        completion(.success(()))
    }

    func request(_ request: SKRequest, didFailWithError error: Error) {
        completion(.failure(error))
    }
}

enum StoreKitLogger {
    static let general = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "ShellReceipt",
        category: "StoreKit"
    )
}

/// Primary StoreKit 1 service providing product loading, purchase handling,
/// restore flow, and receipt utilities for custom validation paths.
@MainActor
final class StoreKitService: NSObject, StoreKitServiceProtocol {
    @Published var products: [SKProduct] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var subscriptionActive = false
    @Published var activeSubscriptionProductIDs: Set<String> = []
    @Published var isRestoring = false
    @Published var isPurchasing = false
    @Published var isValidating = false

    private let productIDs: Set<String>
    private let subscriptionProductIDs: Set<String>
    private var productsRequest: SKProductsRequest?
    private var receiptRefreshDelegate: ReceiptRefreshDelegate?
    var receiptRefreshRequest: SKReceiptRefreshRequest?
    var restoredLogIdentifiers: Set<String> = []
    private var validationDepth = 0

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

    @discardableResult
    func validateWithServer(
        networkHelper: NetworkHelper,
        productID: String?
    ) async throws -> ValidationServerResponse {
        validationDepth += 1
        isValidating = true
        defer {
            validationDepth = max(validationDepth - 1, 0)
            isValidating = validationDepth > 0
        }
        let payload = try await fetchReceiptForServer(productID: productID)
        let response = try await networkHelper.validateReceipt(
            receipt: payload.base64Receipt
        )
        StoreKitLogger.general.info(
            "Server validation completed status=\(response.status, privacy: .public) valid=\(response.valid, privacy: .public)"
        )
        return response
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
