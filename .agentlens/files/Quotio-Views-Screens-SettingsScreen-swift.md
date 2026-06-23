# Quotio/Views/Screens/SettingsScreen.swift

[← Back to Module](../modules/Quotio-Views-Screens/MODULE.md) | [← Back to INDEX](../INDEX.md)

## Overview

- **Lines:** 2965
- **Language:** Swift
- **Symbols:** 63
- **Public symbols:** 0

## Symbol Table

| Line | Kind | Name | Visibility | Signature |
| ---- | ---- | ---- | ---------- | --------- |
| 9 | struct | SettingsScreen | (internal) | `struct SettingsScreen` |
| 87 | struct | OperatingModeSection | (internal) | `struct OperatingModeSection` |
| 152 | fn | handleModeSelection | (private) | `private func handleModeSelection(_ mode: Operat...` |
| 171 | fn | switchToMode | (private) | `private func switchToMode(_ mode: OperatingMode)` |
| 186 | struct | RemoteServerSection | (internal) | `struct RemoteServerSection` |
| 306 | fn | saveRemoteConfig | (private) | `private func saveRemoteConfig(_ config: RemoteC...` |
| 314 | fn | reconnect | (private) | `private func reconnect()` |
| 329 | struct | UnifiedProxySettingsSection | (internal) | `struct UnifiedProxySettingsSection` |
| 547 | fn | loadConfig | (private) | `private func loadConfig() async` |
| 616 | fn | saveProxyURL | (private) | `private func saveProxyURL() async` |
| 645 | fn | saveRoutingStrategy | (private) | `private func saveRoutingStrategy(_ strategy: St...` |
| 662 | fn | saveSwitchProject | (private) | `private func saveSwitchProject(_ enabled: Bool)...` |
| 679 | fn | saveSwitchPreviewModel | (private) | `private func saveSwitchPreviewModel(_ enabled: ...` |
| 696 | fn | saveRequestRetry | (private) | `private func saveRequestRetry(_ count: Int) async` |
| 713 | fn | saveMaxRetryInterval | (private) | `private func saveMaxRetryInterval(_ seconds: In...` |
| 730 | fn | saveLoggingToFile | (private) | `private func saveLoggingToFile(_ enabled: Bool)...` |
| 747 | fn | saveRequestLog | (private) | `private func saveRequestLog(_ enabled: Bool) async` |
| 764 | fn | saveDebugMode | (private) | `private func saveDebugMode(_ enabled: Bool) async` |
| 785 | struct | LocalProxyServerSection | (internal) | `struct LocalProxyServerSection` |
| 859 | struct | NetworkAccessSection | (internal) | `struct NetworkAccessSection` |
| 893 | struct | LocalPathsSection | (internal) | `struct LocalPathsSection` |
| 932 | struct | PathLabel | (internal) | `struct PathLabel` |
| 975 | fn | copyPath | (private) | `private func copyPath()` |
| 981 | fn | revealInFinder | (private) | `private func revealInFinder()` |
| 985 | fn | openFile | (private) | `private func openFile()` |
| 991 | struct | NotificationSettingsSection | (internal) | `struct NotificationSettingsSection` |
| 1061 | struct | QuotaDisplaySettingsSection | (internal) | `struct QuotaDisplaySettingsSection` |
| 1103 | struct | RefreshCadenceSettingsSection | (internal) | `struct RefreshCadenceSettingsSection` |
| 1142 | struct | UpdateSettingsSection | (internal) | `struct UpdateSettingsSection` |
| 1184 | struct | ProxyUpdateSettingsSection | (internal) | `struct ProxyUpdateSettingsSection` |
| 1339 | fn | checkForUpdate | (private) | `private func checkForUpdate()` |
| 1353 | fn | performUpgrade | (private) | `private func performUpgrade(to version: ProxyVe...` |
| 1372 | struct | ProxyVersionManagerSheet | (internal) | `struct ProxyVersionManagerSheet` |
| 1549 | fn | sectionHeader | (private) | `@ViewBuilder   private func sectionHeader(_ tit...` |
| 1564 | fn | isVersionInstalled | (private) | `private func isVersionInstalled(_ version: Stri...` |
| 1568 | fn | refreshInstalledVersions | (private) | `private func refreshInstalledVersions()` |
| 1572 | fn | loadReleases | (private) | `private func loadReleases() async` |
| 1586 | fn | installVersion | (private) | `private func installVersion(_ versionInfo: Prox...` |
| 1599 | fn | performInstall | (private) | `private func performInstall(_ versionInfo: Prox...` |
| 1615 | fn | activateVersion | (private) | `private func activateVersion(_ version: String)` |
| 1633 | fn | deleteVersion | (private) | `private func deleteVersion(_ version: String)` |
| 1644 | struct | NamespacedInstalledVersionItem | (private) | `struct NamespacedInstalledVersionItem` |
| 1649 | struct | NamespacedAvailableVersionItem | (private) | `struct NamespacedAvailableVersionItem` |
| 1656 | struct | InstalledVersionRow | (private) | `struct InstalledVersionRow` |
| 1714 | struct | AvailableVersionRow | (private) | `struct AvailableVersionRow` |
| 1791 | struct | MenuBarSettingsSection | (internal) | `struct MenuBarSettingsSection` |
| 1822 | struct | AppearanceSettingsSection | (internal) | `struct AppearanceSettingsSection` |
| 1851 | struct | PrivacySettingsSection | (internal) | `struct PrivacySettingsSection` |
| 1873 | struct | GeneralSettingsTab | (internal) | `struct GeneralSettingsTab` |
| 1912 | struct | AboutTab | (internal) | `struct AboutTab` |
| 1939 | struct | AboutScreen | (internal) | `struct AboutScreen` |
| 2154 | struct | VersionBadge | (internal) | `struct VersionBadge` |
| 2206 | struct | AboutUpdateCard | (internal) | `struct AboutUpdateCard` |
| 2300 | struct | AboutProxyUpdateCard | (internal) | `struct AboutProxyUpdateCard` |
| 2512 | fn | checkForUpdate | (private) | `private func checkForUpdate()` |
| 2526 | fn | performUpgrade | (private) | `private func performUpgrade(to version: ProxyVe...` |
| 2543 | struct | ProxyBinarySourceOptionBlock | (private) | `struct ProxyBinarySourceOptionBlock` |
| 2582 | struct | ProxyBinarySourceSelectionSheet | (internal) | `struct ProxyBinarySourceSelectionSheet` |
| 2649 | fn | cardHeader | (private) | `private func cardHeader(title: String, systemIm...` |
| 2663 | struct | LinkCard | (internal) | `struct LinkCard` |
| 2750 | struct | ManagementKeyRow | (internal) | `struct ManagementKeyRow` |
| 2844 | struct | LaunchAtLoginToggle | (internal) | `struct LaunchAtLoginToggle` |
| 2902 | struct | UsageDisplaySettingsSection | (internal) | `struct UsageDisplaySettingsSection` |

