//
//  ShellReceiptApp.swift
//  ShellReceipt
//
//  Created by Pongt Chia on 1/11/25.
//

import SwiftUI

@main
struct ShellReceiptApp: App {
    @StateObject private var storeKit1 = StoreKitService()
    @StateObject private var storeKit2 = StoreKit2Service()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(storeKit1)
                .environmentObject(storeKit2)
        }
    }
}
