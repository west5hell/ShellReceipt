//
//  ReceiptRefreshDelegate.swift
//  ShellReceipt
//
//  Created by Pongt Chia on 1/11/25.
//

import Foundation
import StoreKit

/// Lightweight delegate to bridge `SKReceiptRefreshRequest` into continuations.
final class ReceiptRefreshDelegate: NSObject, SKRequestDelegate {
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
