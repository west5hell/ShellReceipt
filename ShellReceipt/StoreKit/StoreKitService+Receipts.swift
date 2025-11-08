//
//  StoreKitService+Receipts.swift
//  ShellReceipt
//
//  Created by Pongt Chia on 1/11/25.
//

import Foundation
import StoreKit

@MainActor
extension StoreKitService {
    /// Load the current receipt from disk or request a refresh if missing.
    func fetchReceiptData() async throws -> Data {
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
    func receiptURL() throws -> URL {
        guard let url = Bundle.main.appStoreReceiptURL else {
            throw ReceiptError.missing
        }
        return url
    }

    /// Bridge StoreKit's receipt refresh callback into async/await.
    func refreshReceipt() async throws {
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
