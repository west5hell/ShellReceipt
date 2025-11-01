//
//  ShellReceiptApp.swift
//  ShellReceipt
//
//  Created by Pongt Chia on 1/11/25.
//

import SwiftUI

@main
struct ShellReceiptApp: App {
    @StateObject private var store = StoreKitService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
