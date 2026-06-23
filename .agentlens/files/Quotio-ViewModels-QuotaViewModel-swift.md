# Quotio/ViewModels/QuotaViewModel.swift

[← Back to Module](../modules/root/MODULE.md) | [← Back to INDEX](../INDEX.md)

## Overview

- **Lines:** 1962
- **Language:** Swift
- **Symbols:** 95
- **Public symbols:** 0

## Symbol Table

| Line | Kind | Name | Visibility | Signature |
| ---- | ---- | ---- | ---------- | --------- |
| 11 | class | QuotaViewModel | (internal) | `class QuotaViewModel` |
| 139 | fn | loadDisabledAuthFiles | (private) | `private func loadDisabledAuthFiles() -> Set<Str...` |
| 145 | fn | saveDisabledAuthFiles | (private) | `private func saveDisabledAuthFiles(_ names: Set...` |
| 150 | fn | syncDisabledStatesToBackend | (private) | `private func syncDisabledStatesToBackend() async` |
| 169 | fn | notifyQuotaDataChanged | (private) | `private func notifyQuotaDataChanged()` |
| 172 | method | init | (internal) | `init()` |
| 181 | fn | setupProxyURLObserver | (private) | `private func setupProxyURLObserver()` |
| 197 | fn | normalizedProxyURL | (private) | `private func normalizedProxyURL(_ rawValue: Str...` |
| 209 | fn | updateProxyConfiguration | (internal) | `func updateProxyConfiguration() async` |
| 222 | fn | setupRefreshCadenceCallback | (private) | `private func setupRefreshCadenceCallback()` |
| 230 | fn | setupWarmupCallback | (private) | `private func setupWarmupCallback()` |
| 242 | fn | cancelHiddenWarmup | (private) | `private func cancelHiddenWarmup()` |
| 247 | fn | restartAutoRefresh | (private) | `private func restartAutoRefresh()` |
| 254 | fn | initialize | (internal) | `func initialize() async` |
| 264 | fn | initializeFullMode | (private) | `private func initializeFullMode() async` |
| 284 | fn | checkForProxyUpgrade | (private) | `private func checkForProxyUpgrade() async` |
| 289 | fn | initializeQuotaOnlyMode | (private) | `private func initializeQuotaOnlyMode() async` |
| 293 | fn | initializeRemoteMode | (private) | `private func initializeRemoteMode() async` |
| 321 | fn | setupRemoteAPIClient | (private) | `private func setupRemoteAPIClient(config: Remot...` |
| 329 | fn | reconnectRemote | (internal) | `func reconnectRemote() async` |
| 338 | fn | loadDirectAuthFiles | (internal) | `func loadDirectAuthFiles() async` |
| 344 | fn | refreshQuotasDirectly | (internal) | `func refreshQuotasDirectly() async` |
| 372 | fn | autoSelectMenuBarItems | (private) | `private func autoSelectMenuBarItems()` |
| 406 | fn | syncMenuBarSelection | (internal) | `func syncMenuBarSelection()` |
| 413 | fn | refreshClaudeCodeQuotasInternal | (private) | `private func refreshClaudeCodeQuotasInternal() ...` |
| 434 | fn | refreshCursorQuotasInternal | (private) | `private func refreshCursorQuotasInternal() async` |
| 445 | fn | refreshCodexCLIQuotasInternal | (private) | `private func refreshCodexCLIQuotasInternal() async` |
| 461 | fn | refreshGeminiCLIQuotasInternal | (private) | `private func refreshGeminiCLIQuotasInternal() a...` |
| 509 | fn | refreshGlmQuotasInternal | (private) | `private func refreshGlmQuotasInternal() async` |
| 519 | fn | refreshWarpQuotasInternal | (private) | `private func refreshWarpQuotasInternal() async` |
| 543 | fn | refreshTraeQuotasInternal | (private) | `private func refreshTraeQuotasInternal() async` |
| 553 | fn | refreshKiroQuotasInternal | (private) | `private func refreshKiroQuotasInternal() async` |
| 559 | fn | cleanName | (internal) | `func cleanName(_ name: String) -> String` |
| 607 | fn | startQuotaOnlyAutoRefresh | (private) | `private func startQuotaOnlyAutoRefresh()` |
| 625 | fn | startQuotaAutoRefreshWithoutProxy | (private) | `private func startQuotaAutoRefreshWithoutProxy()` |
| 644 | fn | isWarmupEnabled | (internal) | `func isWarmupEnabled(for provider: AIProvider, ...` |
| 648 | fn | warmupStatus | (internal) | `func warmupStatus(provider: AIProvider, account...` |
| 653 | fn | warmupNextRunDate | (internal) | `func warmupNextRunDate(provider: AIProvider, ac...` |
| 658 | fn | toggleWarmup | (internal) | `func toggleWarmup(for provider: AIProvider, acc...` |
| 667 | fn | setWarmupEnabled | (internal) | `func setWarmupEnabled(_ enabled: Bool, provider...` |
| 679 | fn | nextDailyRunDate | (private) | `private func nextDailyRunDate(minutes: Int, now...` |
| 690 | fn | restartWarmupScheduler | (private) | `private func restartWarmupScheduler()` |
| 723 | fn | runWarmupCycle | (private) | `private func runWarmupCycle() async` |
| 786 | fn | warmupAccount | (private) | `private func warmupAccount(provider: AIProvider...` |
| 831 | fn | warmupAccount | (private) | `private func warmupAccount(     provider: AIPro...` |
| 892 | fn | fetchWarmupModels | (private) | `private func fetchWarmupModels(     provider: A...` |
| 916 | fn | warmupAvailableModels | (internal) | `func warmupAvailableModels(provider: AIProvider...` |
| 929 | fn | warmupAuthInfo | (private) | `private func warmupAuthInfo(provider: AIProvide...` |
| 951 | fn | warmupTargets | (private) | `private func warmupTargets() -> [WarmupAccountKey]` |
| 965 | fn | updateWarmupStatus | (private) | `private func updateWarmupStatus(for key: Warmup...` |
| 994 | fn | startProxy | (internal) | `func startProxy() async` |
| 1016 | fn | configureProxyBridgeCallbacks | (private) | `private func configureProxyBridgeCallbacks()` |
| 1022 | fn | attachProxyControlSurface | (private) | `private func attachProxyControlSurface()` |
| 1028 | fn | stopProxy | (internal) | `func stopProxy()` |
| 1055 | fn | toggleProxy | (internal) | `func toggleProxy() async` |
| 1063 | fn | setupAPIClient | (private) | `private func setupAPIClient()` |
| 1070 | fn | startAutoRefresh | (private) | `private func startAutoRefresh()` |
| 1107 | fn | attemptProxyRecovery | (private) | `private func attemptProxyRecovery() async` |
| 1129 | fn | refreshData | (internal) | `func refreshData() async` |
| 1182 | fn | manualRefresh | (internal) | `func manualRefresh() async` |
| 1193 | fn | refreshAllQuotas | (internal) | `func refreshAllQuotas() async` |
| 1233 | fn | refreshQuotasUnified | (internal) | `func refreshQuotasUnified() async` |
| 1267 | fn | refreshAntigravityQuotasInternal | (private) | `private func refreshAntigravityQuotasInternal()...` |
| 1287 | fn | refreshAntigravityQuotasWithoutDetect | (private) | `private func refreshAntigravityQuotasWithoutDet...` |
| 1304 | fn | isAntigravityAccountActive | (internal) | `func isAntigravityAccountActive(email: String) ...` |
| 1309 | fn | switchAntigravityAccount | (internal) | `func switchAntigravityAccount(email: String) async` |
| 1319 | fn | beginAntigravitySwitch | (internal) | `func beginAntigravitySwitch(accountId: String, ...` |
| 1324 | fn | cancelAntigravitySwitch | (internal) | `func cancelAntigravitySwitch()` |
| 1329 | fn | dismissAntigravitySwitchResult | (internal) | `func dismissAntigravitySwitchResult()` |
| 1332 | fn | refreshOpenAIQuotasInternal | (private) | `private func refreshOpenAIQuotasInternal() async` |
| 1337 | fn | refreshCopilotQuotasInternal | (private) | `private func refreshCopilotQuotasInternal() async` |
| 1342 | fn | refreshQuotaForProvider | (internal) | `func refreshQuotaForProvider(_ provider: AIProv...` |
| 1377 | fn | refreshAutoDetectedProviders | (internal) | `func refreshAutoDetectedProviders() async` |
| 1384 | fn | startOAuth | (internal) | `func startOAuth(for provider: AIProvider, proje...` |
| 1429 | fn | startCopilotAuth | (private) | `private func startCopilotAuth() async` |
| 1446 | fn | startKiroAuth | (private) | `private func startKiroAuth(method: AuthCommand)...` |
| 1486 | fn | pollCopilotAuthCompletion | (private) | `private func pollCopilotAuthCompletion() async` |
| 1503 | fn | pollKiroAuthCompletion | (private) | `private func pollKiroAuthCompletion() async` |
| 1526 | fn | pollOAuthStatus | (private) | `private func pollOAuthStatus(state: String, pro...` |
| 1554 | fn | cancelOAuth | (internal) | `func cancelOAuth()` |
| 1558 | fn | deleteAuthFile | (internal) | `func deleteAuthFile(_ file: AuthFile) async` |
| 1594 | fn | toggleAuthFileDisabled | (internal) | `func toggleAuthFileDisabled(_ file: AuthFile) a...` |
| 1625 | fn | pruneMenuBarItems | (private) | `private func pruneMenuBarItems()` |
| 1661 | fn | importVertexServiceAccount | (internal) | `func importVertexServiceAccount(url: URL) async` |
| 1685 | fn | fetchAPIKeys | (internal) | `func fetchAPIKeys() async` |
| 1695 | fn | addAPIKey | (internal) | `func addAPIKey(_ key: String) async` |
| 1707 | fn | updateAPIKey | (internal) | `func updateAPIKey(old: String, new: String) async` |
| 1719 | fn | deleteAPIKey | (internal) | `func deleteAPIKey(_ key: String) async` |
| 1732 | fn | checkAccountStatusChanges | (private) | `private func checkAccountStatusChanges()` |
| 1753 | fn | checkQuotaNotifications | (internal) | `func checkQuotaNotifications()` |
| 1785 | fn | scanIDEsWithConsent | (internal) | `func scanIDEsWithConsent(options: IDEScanOption...` |
| 1855 | fn | savePersistedIDEQuotas | (private) | `private func savePersistedIDEQuotas()` |
| 1878 | fn | loadPersistedIDEQuotas | (private) | `private func loadPersistedIDEQuotas()` |
| 1940 | fn | shortenAccountKey | (private) | `private func shortenAccountKey(_ key: String) -...` |
| 1952 | struct | OAuthState | (internal) | `struct OAuthState` |

## Memory Markers

### 🟢 `NOTE` (line 343)

> Cursor and Trae are NOT auto-refreshed - user must use "Scan for IDEs" (issue #29)

### 🟢 `NOTE` (line 351)

> Cursor and Trae removed from auto-refresh to address privacy concerns (issue #29)

### 🟢 `NOTE` (line 1205)

> Cursor and Trae removed from auto-refresh (issue #29)

### 🟢 `NOTE` (line 1232)

> Cursor and Trae require explicit user scan (issue #29)

### 🟢 `NOTE` (line 1242)

> Cursor and Trae removed - require explicit scan (issue #29)

### 🟢 `NOTE` (line 1297)

> Don't call detectActiveAccount() here - already set by switch operation

