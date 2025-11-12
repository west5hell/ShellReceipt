# Repository Guidelines

## Project Structure & Module Organization

The app lives under `ShellReceipt/`, with SwiftUI entry point `ShellReceiptApp.swift`, shared state under `StoreKit/StoreKitService.swift` (+ extensions), and feature views such as `ConsumableProductsView.swift`, `SubscriptionProductsView.swift`, and `WebView.swift`. UI resources stay in `Assets.xcassets`, while the in-app purchase bridge for web demos sits in `demo.html`. Keep StoreKit-facing logic isolated in the `StoreKit/` folder, and do all product ID/shared-secret updates via `StoreKit/ProductIdentifiers.swift` (`ProductCatalog`) so migrations require editing a single file.

## Build, Test, and Development Commands

- `xed ShellReceipt.xcodeproj` – open the project in Xcode for day-to-day development.
- `xcodebuild -project ShellReceipt.xcodeproj -scheme ShellReceipt -destination 'platform=iOS Simulator,name=iPhone 15' build` – headless build that matches CI expectations; fails fast on API or asset issues.
- `xcodebuild -project ShellReceipt.xcodeproj -scheme ShellReceipt -destination 'platform=iOS Simulator,name=iPhone 15' test` – runs XCTest targets when present; use it locally before pushing even if the suite is empty to surface configuration regressions.

## Coding Style & Naming Conventions

Follow the Swift API Design Guidelines: 4-space indentation, `PascalCase` for types, `camelCase` for properties/functions, and mark async store actions `@MainActor` as done in `StoreKitService`. Keep modifiers grouped (`.task`, `.sheet`, `.alert`) and prefer computed properties over long view builders. Wrap user-facing strings in `LocalizedStringKey` when adding new UI text. No formatter is enforced, so let Xcode’s “Re-Indent” run before committing.

## Testing Guidelines

Add XCTest targets mirroring the module (e.g., `ShellReceiptTests`). Name tests `test_purchaseFlowRestoresState_when...` to emphasize behavior. Exercise receipt parsing and request paths via dependency-injected stubs for `StoreKitService`, and describe any manual purchase/restore checks in PRs so reviewers can replay them.

## Commit & Pull Request Guidelines

Follow the existing history by using imperative, descriptive subjects (`Enhance README.md…`). Scope commits by feature slice (service change, UI tweak, docs). PRs should include: summary of user impact, testing notes (`xcodebuild test`, manual scenarios), linked issues, and screenshots or console excerpts for StoreKit flows so reviewers can verify receipts without rerunning everything.

## Security & Configuration Tips

Never commit shared secrets; `ProductCatalog.appleSharedSecret` should come from secure storage in production, and the sample `NetworkHelper` only targets localhost for development. When touching `demo.html`, ensure `window.webkit.messageHandlers.purchase` remains the only exposed bridge and sanitize incoming product IDs before passing them into StoreKit.
