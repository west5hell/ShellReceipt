//
//  AppleReceiptValidator.swift
//  ShellReceipt
//
//  Created by Pongt Chia on 1/11/25.
//

import Foundation

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
