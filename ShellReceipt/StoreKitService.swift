//
//  StoreKitService.swift
//  ShellReceipt
//
//  Created by Pongt Chia on 1/11/25.
//

import Combine
import Foundation
import StoreKit

/// Describes how receipts should be verified.
enum ReceiptValidationMode {
    /// Hand the receipt to Apple for official validation.
    case apple(sharedSecret: String?)
    /// Skip Apple and return the raw receipt for a custom server.
    case customServer
}

/// Encapsulates the data required for remote receipt verification.
struct ReceiptPayload {
    let base64Receipt: String
    let productID: String?
}

/// Outcome of a receipt verification attempt.
struct ReceiptValidationResult {
    let activeSubscriptions: Set<String>
    let environment: ReceiptEnvironment
    let rawBody: [String: Any]
}

/// Apple verification endpoints.
enum ReceiptEnvironment {
    case production
    case sandbox

    var url: URL {
        switch self {
        case .production:
            return URL(string: "https://buy.itunes.apple.com/verifyReceipt")!
        case .sandbox:
            return URL(
                string: "https://sandbox.itunes.apple.com/verifyReceipt"
            )!
        }
    }

    var description: String {
        switch self {
        case .production:
            return "production"
        case .sandbox:
            return "sandbox"
        }
    }

    init(string: String) {
        switch string.lowercased() {
        case "sandbox":
            self = .sandbox
        default:
            self = .production
        }
    }
}

protocol ReceiptValidating {
    func validate(receiptData: Data, productID: String?) async throws
        -> ReceiptValidationResult
}

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
    /// Return the latest receipt encoded for custom server validation.
    /// Return the latest receipt encoded for consumption by a custom server.
    func fetchReceiptForServer(productID: String?) async throws
        -> ReceiptPayload
}

/// Primary StoreKit 1 service providing product loading, purchase handling,
/// restore flow, and receipt utilities for Apple or custom validation paths.
@MainActor
final class StoreKitService: NSObject, StoreKitServiceProtocol {
    @Published private(set) var products: [SKProduct] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var subscriptionActive = false
    @Published private(set) var activeSubscriptionProductIDs: Set<String> = []
    @Published private(set) var isRestoring = false
    @Published private(set) var isPurchasing = false

    private let productIDs: Set<String>
    private let subscriptionProductIDs: Set<String>
    private var productsRequest: SKProductsRequest?
    private var receiptRefreshDelegate: ReceiptRefreshDelegate?
    private var receiptRefreshRequest: SKReceiptRefreshRequest?

    init(
        productIDs: Set<String> = [
            "com.example.consumable.coffee",
            "com.example.premium.monthly",
            "com.example.premium.yearly",
        ],
        subscriptionProductIDs: Set<String> = [
            "com.example.premium.monthly",
            "com.example.premium.yearly",
        ]
    ) {
        self.productIDs = productIDs
        self.subscriptionProductIDs = subscriptionProductIDs
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
            print("[StoreKit] Purchases disabled on this device.")
            return
        }
        isPurchasing = true
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }

    /// Trigger StoreKit's restore flow for this queue.
    func restorePurchases() {
        isRestoring = true
        SKPaymentQueue.default().restoreCompletedTransactions()
    }

    func validateWithApple(sharedSecret: String?, productID: String?)
        async throws -> ReceiptValidationResult
    {
        let receiptData = try await fetchReceiptData()
        let result = try await AppleReceiptValidator(
            subscriptionProductIDs: subscriptionProductIDs,
            sharedSecret: sharedSecret
        ).validate(receiptData: receiptData, productID: productID)
        activeSubscriptionProductIDs = result.activeSubscriptions
        subscriptionActive = !result.activeSubscriptions.isEmpty
        print(
            "[Apple Validation] environment=\(result.environment.description) active=\(subscriptionActive)"
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
        print(
            "[Server Receipt] product=\(productID ?? "unknown") length=\(payload.base64Receipt.count)"
        )
        return payload
    }
}

// MARK: - Private helpers

@MainActor
extension StoreKitService {
    /// Load the current receipt from disk or request a refresh if missing.
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

    /// Helper returning the expected receipt location on disk.
    fileprivate func receiptURL() throws -> URL {
        guard let url = Bundle.main.appStoreReceiptURL else {
            throw ReceiptError.missing
        }
        return url
    }

    /// Bridge StoreKit's receipt refresh callback into async/await.
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

// MARK: - SKPaymentTransactionObserver

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

// MARK: - Receipt refresh delegate

/// Lightweight delegate to bridge `SKReceiptRefreshRequest` into continuations.
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

// MARK: - Receipt validation utilities

/// Minimal validator that calls Apple's verifyReceipt endpoint.
struct AppleReceiptValidator: ReceiptValidating {
    enum ValidationError: Error {
        case invalidJSON
        case unknownStatus
    }

    private let subscriptionProductIDs: Set<String>
    private let sharedSecret: String?

    init(
        subscriptionProductIDs: Set<String>,
        sharedSecret: String? = nil
    ) {
        self.subscriptionProductIDs = subscriptionProductIDs
        self.sharedSecret = sharedSecret
    }

    func validate(receiptData: Data, productID: String?) async throws
        -> ReceiptValidationResult
    {
        try await validate(receiptData: receiptData, against: .production)
    }

    private func validate(
        receiptData: Data,
        against environment: ReceiptEnvironment
    ) async throws -> ReceiptValidationResult {
        var request = URLRequest(url: environment.url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "receipt-data": receiptData.base64EncodedString()
        ]
        if let sharedSecret {
            body["password"] = sharedSecret
        }
        request.httpBody = try JSONSerialization.data(
            withJSONObject: body,
            options: []
        )

        let (data, _) = try await URLSession.shared.data(for: request)
        guard
            let json = try JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        else {
            throw ValidationError.invalidJSON
        }

        if let status = json["status"] as? Int, status == 21007,
            environment == .production
        {
            return try await validate(
                receiptData: receiptData,
                against: .sandbox
            )
        }

        guard let status = json["status"] as? Int else {
            throw ValidationError.unknownStatus
        }

        if status != 0 {
            throw ValidationError.unknownStatus
        }

        let active = evaluateSubscriptionStatus(from: json, status: status)
        return ReceiptValidationResult(
            activeSubscriptions: active,
            environment: environment,
            rawBody: json
        )
    }

    private func evaluateSubscriptionStatus(
        from json: [String: Any],
        status: Int
    ) -> Set<String> {
        guard status == 0 else { return [] }
        let now = Date()
        var activeIDs: Set<String> = []

        if let latestInfo = json["latest_receipt_info"] as? [[String: Any]] {
            activeIDs.formUnion(activeSubscriptions(from: latestInfo, now: now))
        }
        return activeIDs
    }

    private func activeSubscriptions(from entries: [[String: Any]], now: Date)
        -> Set<String>
    {
        var activeIDs: Set<String> = []

        for entry in entries {
            guard
                let productID = entry["product_id"] as? String,
                subscriptionProductIDs.contains(productID)
            else { continue }

            if let expiresValue = entry["expires_date_ms"] {
                let interval: Double?
                if let string = expiresValue as? String {
                    interval = Double(string)
                } else if let number = expiresValue as? NSNumber {
                    interval = number.doubleValue
                } else {
                    interval = nil
                }

                if let expiresInterval = interval {
                    let expiryDate = Date(
                        timeIntervalSince1970: expiresInterval / 1000.0
                    )
                    if expiryDate > now {
                        activeIDs.insert(productID)
                    }
                    continue
                }
            }

            if entry["expires_date"] == nil {
                activeIDs.insert(productID)
            }
        }

        return activeIDs
    }
}

enum ReceiptError: Error {
    case missing
    case empty
}

extension SKProduct {
    var identifiableID: String { productIdentifier }
}
