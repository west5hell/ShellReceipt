# ShellReceipt

示例项目演示了如何在 **SwiftUI + StoreKit 2** 环境中展示消耗型/订阅型商品，并通过苹果验证自动刷新订阅状态；同时保留一个 StoreKit 1 + WebView 示例来说明如何将 receipt 交给自建服务器验单。

## 功能概览

- 加载内购商品（消耗型、订阅型），基于 StoreKit 2 的 SwiftUI 列表
- 购买、恢复购买，自动通过苹果验单（StoreKit 2）刷新订阅状态
- WebView 场景下可将 receipt 返回自建服务器进行验单
- WebView 内执行购买请求并走服务器验单
- UI 层提供 SwiftUI 商品列表，并在购买/恢复期间显示全屏进度遮罩

## 快速接入 `StoreKitService`

   1. **复制文件**

   - `ShellReceipt/StoreKit/ProductIdentifiers.swift`（集中配置商品 ID 与 shared secret）
   - `ShellReceipt/StoreKit/` 下的 StoreKit 服务文件（`StoreKitService.swift` 及同目录扩展）
   - `ShellReceipt/WebView.swift`（如需 WebView 场景）
   - `ShellReceipt/demo.html`（可选，演示用）
   - `ShellReceipt/NetworkHelper`（示例网络工具，可替换为项目内实现）

   其中 `StoreKit/ProductIdentifiers.swift` 暴露 `ProductCatalog`，集中存放所有商品 ID 与 Apple shared secret，迁移到其他项目时只需修改该文件即可。

2. **初始化服务**

   ```swift
   @main
   struct YourApp: App {
       @StateObject private var storeKit2 = StoreKit2Service()
       @StateObject private var legacyStore = StoreKitService() // 仅在需要 WebView 验单时使用

       var body: some Scene {
           WindowGroup {
               ContentView()
                   .environmentObject(storeKit2)
                   .environmentObject(legacyStore)
           }
       }
   }
   ```

3. **加载商品 & 购买（StoreKit 2）**

   ```swift
   @EnvironmentObject private var store: StoreKit2Service

   // 加载商品 & 刷新订阅状态
   .task {
       await store.loadProducts()
       await store.refreshEntitlements()
   }

   // 购买
   store.purchase(product: product)

   // 恢复购买
   store.restorePurchases()
   ```

4. **StoreKit 2 验单（苹果）**

   ```swift
   @StateObject private var storeKit2 = StoreKit2Service()

   var body: some View {
       ConsumableProductsView()
           .environmentObject(storeKit2)
           .task {
               await storeKit2.loadProducts()
               await storeKit2.refreshEntitlements()
           }
   }
   ```

5. **WebView 场景（服务器验单，可选）**
   - `WebView` 组件在 `demo.html` 中监听购买按钮，通过 `window.webkit.messageHandlers.purchase.postMessage` 将商品 ID 传回原生层。
   - `StoreKitService` 完成购买后调用 `fetchReceiptForServer` 并通过 `NetworkHelper` 将收据发送到本地/远端验证服务。

## 注意事项

- 商品/订阅 ID 在 `ProductIdentifiers.swift` 内集中维护；移植时根据实际情况调整或改为配置化。
- `NetworkHelper` 默认连接 `http://127.0.0.1:3000/verify`（可搭配 `ValidationServer/Server-go`），若有自建后端可在初始化时传入实际 host、port，并通过 `StoreKitService.validateWithServer` 发送收据。
- 所有日志均打印到 Xcode 控制台；正式项目可加用户提示、错误上报等。
- StoreKit 2 服务使用 `@MainActor` 管理状态，并通过 `Transaction.currentEntitlements`/`Transaction.updates` 自动刷新订阅状态；StoreKit 1 服务用于 WebView + 服务器验单示例。

## 运行 Demo

1. 使用 Xcode 打开 `ShellReceipt.xcodeproj`
2. 运行到模拟器/真机
3. 进入 “消耗型商品”“订阅商品” 体验购买与恢复，“WebView 购买示例” 展示自建服务器验单流程
4. 查看 Xcode 控制台了解购买、验单日志输出

欢迎基于此项目扩展更多内购管理逻辑（收据缓存、策略配置、多环境等）。如有问题可自行调整或提 Issue。祝开发顺利！
