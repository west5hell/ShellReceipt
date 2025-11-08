//
//  StoreKitLogger.swift
//  ShellReceipt
//
//  Created by Pongt Chia on 1/11/25.
//

import Foundation
import os.log

enum StoreKitLogger {
    static let general = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "ShellReceipt",
        category: "StoreKit"
    )
}
