//
//  StoreKit2Service.swift
//  ShellReceipt
//
//  Created by Pongt Chia on 1/12/25.
//

import Combine
import Foundation
import os.log
import StoreKit

@MainActor
final class StoreKit2Service: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var activeSubscriptionProductIDs: Set<String> = []
    @Published private(set) var subscriptionActive = false
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRestoring = false
    @Published private(set) var isValidating = false

    private var updatesTask: Task<Void, Never>?

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "ShellReceipt",
        category: "StoreKit2"
    )

    init() {
        updatesTask = listenForTransactions()
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProductsIfNeeded() async {
        guard products.isEmpty else { return }
        await loadProducts()
    }

    func loadProducts() async {
        guard isLoadingProducts == false else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let fetched = try await Product.products(
                for: Array(ProductCatalog.allProducts)
            )
            products = fetched.sorted(by: { $0.id < $1.id })
        } catch {
            logger.error("Failed to load products: \(error.localizedDescription, privacy: .public)")
        }
    }

    func purchase(product: Product) async -> String {
        guard isPurchasing == false else { return "Purchase already in progress." }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                updateState(with: transaction)
                await transaction.finish()
                return "Purchase completed."
            case .userCancelled:
                return "Purchase cancelled."
            case .pending:
                return "Purchase pending."
            @unknown default:
                return "Unknown purchase state."
            }
        } catch {
            logger.error("Purchase failed: \(error.localizedDescription, privacy: .public)")
            return "Purchase failed: \(error.localizedDescription)"
        }
    }

    func restorePurchases() {
        guard isRestoring == false else { return }
        isRestoring = true
        Task { [weak self] in
            guard let self else { return }
            defer { self.isRestoring = false }
            do {
                try await AppStore.sync()
            } catch {
                logger.error("Restore failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func refreshEntitlements() async {
        guard isValidating == false else { return }
        isValidating = true
        defer { isValidating = false }
        var purchases: Set<String> = []
        var activeSubs: Set<String> = []
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                purchases.insert(transaction.productID)
                if ProductCatalog.subscriptionProducts.contains(
                    transaction.productID
                ) {
                    activeSubs.insert(transaction.productID)
                }
            } catch {
                continue
            }
        }
        purchasedProductIDs = purchases
        activeSubscriptionProductIDs = activeSubs
        subscriptionActive = activeSubs.isEmpty == false
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    self.updateState(with: transaction)
                    await transaction.finish()
                } catch {
                    continue
                }
            }
        }
    }

    private func updateState(with transaction: Transaction) {
        purchasedProductIDs.insert(transaction.productID)
        if ProductCatalog.subscriptionProducts.contains(transaction.productID) {
            activeSubscriptionProductIDs.insert(transaction.productID)
            subscriptionActive = true
        }
    }

    private func checkVerified(
        _ result: VerificationResult<Transaction>
    ) throws -> Transaction {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified(_, let error):
            throw error
        }
    }
}
