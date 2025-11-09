//
//  WebView.swift
//  ShellReceipt
//
//  Created by Pongt Chia on 1/11/25.
//

import Combine
import StoreKit
import SwiftUI
import WebKit

struct WebView: UIViewControllerRepresentable {
    @EnvironmentObject var store: StoreKitService
    private let networkHelper = NetworkHelper()

    func makeUIViewController(context: Context) -> CustomsWebController {
        return CustomsWebController(store: store, networkHelper: networkHelper)
    }

    func updateUIViewController(
        _ uiViewController: CustomsWebController,
        context: Context
    ) {

    }
}

class CustomsWebController: UIViewController, WKScriptMessageHandler {
    var webView: WKWebView!
    private let store: StoreKitService
    private let networkHelper: NetworkHelper
    private var cancellables = Set<AnyCancellable>()
    private var pendingProductID: String?
    private var awaitingServerValidation = false
    private let messageName = "purchase"

    init(store: StoreKitService, networkHelper: NetworkHelper) {
        self.store = store
        self.networkHelper = networkHelper
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let userContentController = WKUserContentController()
        userContentController.add(self, name: messageName)

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController

        webView = WKWebView(frame: .zero, configuration: configuration)
        view = webView

        store.$products
            .receive(on: RunLoop.main)
            .sink { [weak self] products in
                guard
                    let self,
                    self.awaitingServerValidation,
                    let pendingID = self.pendingProductID,
                    let product = products.first(where: {
                        $0.productIdentifier == pendingID
                    })
                else { return }
                self.initiatePurchase(for: product, productID: pendingID)
            }
            .store(in: &cancellables)

        store.$purchasedProductIDs
            .receive(on: RunLoop.main)
            .sink { [weak self] purchasedIDs in
                guard
                    let self,
                    self.awaitingServerValidation,
                    let pendingID = self.pendingProductID,
                    purchasedIDs.contains(pendingID)
                else { return }
                self.processServerValidation(for: pendingID)
            }
            .store(in: &cancellables)

        if store.products.isEmpty {
            store.reloadProducts()
        }

        if let url = Bundle.main.url(forResource: "demo", withExtension: "html")
        {
            webView.loadFileURL(
                url,
                allowingReadAccessTo: url.deletingLastPathComponent()
            )
        } else {
            print("[WebView] demo.html not found in bundle.")
        }
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == messageName else { return }

        if let body = message.body as? [String: Any],
            let productID = body["productID"] as? String
        {
            handlePurchaseRequest(for: productID)
        } else if let productID = message.body as? String {
            handlePurchaseRequest(for: productID)
        }
    }

    private func handlePurchaseRequest(for productID: String) {
        pendingProductID = productID
        awaitingServerValidation = true

        if let product = store.products.first(where: {
            $0.productIdentifier == productID
        }) {
            initiatePurchase(for: product, productID: productID)
        } else {
            store.reloadProducts()
        }
    }

    private func initiatePurchase(for product: SKProduct, productID: String) {
        store.purchase(product: product)
    }

    private func processServerValidation(for productID: String) {
        Task { [weak self] in
            guard let self else { return }
            do {
                let payload = try await store.fetchReceiptForServer(
                    productID: productID
                )
                let resolvedID = payload.productID ?? productID
                let response = try await networkHelper.validateReceipt(
                    receipt: payload.base64Receipt,
                    productID: resolvedID
                )
                print(
                    "[Server Receipt] web status=\(response.status) valid=\(response.valid)"
                )
            } catch {
                print(
                    "[Server Receipt] web validation error: \(error.localizedDescription)"
                )
            }
            await MainActor.run {
                self.awaitingServerValidation = false
                self.pendingProductID = nil
            }
        }
    }

    deinit {
        webView?.configuration.userContentController.removeScriptMessageHandler(
            forName: messageName
        )
    }
}
