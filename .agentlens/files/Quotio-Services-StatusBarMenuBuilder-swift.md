# Quotio/Services/StatusBarMenuBuilder.swift

[← Back to Module](../modules/root/MODULE.md) | [← Back to INDEX](../INDEX.md)

## Overview

- **Lines:** 1439
- **Language:** Swift
- **Symbols:** 45
- **Public symbols:** 0

## Symbol Table

| Line | Kind | Name | Visibility | Signature |
| ---- | ---- | ---- | ---------- | --------- |
| 18 | class | StatusBarMenuBuilder | (internal) | `class StatusBarMenuBuilder` |
| 33 | method | init | (internal) | `init(viewModel: QuotaViewModel)` |
| 39 | fn | buildMenu | (internal) | `func buildMenu() -> NSMenu` |
| 85 | fn | isCLIInstalled | (private) | `private func isCLIInstalled(_ agent: CLIAgent) ...` |
| 109 | fn | checkBinaryExists | (private) | `private func checkBinaryExists(names: [String])...` |
| 138 | fn | resolveSelectedProvider | (private) | `private func resolveSelectedProvider(from provi...` |
| 147 | fn | accountsForProvider | (private) | `private func accountsForProvider(_ provider: AI...` |
| 154 | fn | buildHeaderItem | (private) | `private func buildHeaderItem() -> NSMenuItem` |
| 161 | fn | buildNetworkInfoItem | (private) | `private func buildNetworkInfoItem() -> NSMenuItem` |
| 188 | fn | buildAccountCardItem | (private) | `private func buildAccountCardItem(     email: S...` |
| 219 | fn | buildAntigravitySubmenu | (private) | `private func buildAntigravitySubmenu(data: Prov...` |
| 235 | fn | showSwitchConfirmation | (private) | `private static func showSwitchConfirmation(emai...` |
| 264 | fn | buildEmptyStateItem | (private) | `private func buildEmptyStateItem() -> NSMenuItem` |
| 271 | fn | buildActionItems | (private) | `private func buildActionItems() -> [NSMenuItem]` |
| 295 | class | MenuActionHandler | (internal) | `class MenuActionHandler` |
| 304 | fn | openApp | (internal) | `@objc func openApp()` |
| 308 | fn | quit | (internal) | `@objc func quit()` |
| 312 | fn | openMainWindow | (internal) | `static func openMainWindow()` |
| 337 | struct | MenuHeaderView | (private) | `struct MenuHeaderView` |
| 362 | struct | MenuProviderSectionHeader | (private) | `struct MenuProviderSectionHeader` |
| 380 | struct | MenuProviderPickerView | (private) | `struct MenuProviderPickerView` |
| 415 | struct | ProviderFilterButton | (private) | `struct ProviderFilterButton` |
| 447 | struct | ProviderIconMono | (private) | `struct ProviderIconMono` |
| 471 | struct | MenuNetworkInfoView | (private) | `struct MenuNetworkInfoView` |
| 600 | fn | triggerCopyState | (private) | `private func triggerCopyState(_ target: CopyTar...` |
| 611 | fn | setCopied | (private) | `private func setCopied(_ target: CopyTarget, va...` |
| 622 | fn | copyButton | (private) | `@ViewBuilder   private func copyButton(isCopied...` |
| 639 | struct | MenuAccountCardView | (private) | `struct MenuAccountCardView` |
| 678 | fn | planConfig | (private) | `private func planConfig(for planName: String) -...` |
| 910 | fn | formatLocalTime | (private) | `private func formatLocalTime(_ isoString: Strin...` |
| 929 | struct | ModelBadgeData | (private) | `struct ModelBadgeData` |
| 968 | struct | AntigravityDisplayGroup | (private) | `struct AntigravityDisplayGroup` |
| 975 | fn | menuDisplayPercent | (private) | `private func menuDisplayPercent(remainingPercen...` |
| 979 | fn | menuStatusColor | (private) | `private func menuStatusColor(remainingPercent: ...` |
| 997 | struct | LowestBarLayout | (private) | `struct LowestBarLayout` |
| 1077 | struct | RingGridLayout | (private) | `struct RingGridLayout` |
| 1121 | struct | CardGridLayout | (private) | `struct CardGridLayout` |
| 1170 | struct | ModernProgressBar | (private) | `struct ModernProgressBar` |
| 1205 | struct | PercentageBadge | (private) | `struct PercentageBadge` |
| 1241 | struct | MenuModelDetailView | (private) | `struct MenuModelDetailView` |
| 1293 | struct | MenuEmptyStateView | (private) | `struct MenuEmptyStateView` |
| 1308 | struct | MenuViewMoreAccountsView | (private) | `struct MenuViewMoreAccountsView` |
| 1356 | mod | extension AIProvider | (private) | - |
| 1378 | struct | MenuActionsView | (private) | `struct MenuActionsView` |
| 1405 | struct | MenuBarActionButton | (private) | `struct MenuBarActionButton` |

