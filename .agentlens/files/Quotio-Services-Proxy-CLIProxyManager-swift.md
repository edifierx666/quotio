# Quotio/Services/Proxy/CLIProxyManager.swift

[← Back to Module](../modules/root/MODULE.md) | [← Back to INDEX](../INDEX.md)

## Overview

- **Lines:** 2622
- **Language:** Swift
- **Symbols:** 97
- **Public symbols:** 0

## Symbol Table

| Line | Kind | Name | Visibility | Signature |
| ---- | ---- | ---- | ---------- | --------- |
| 9 | class | CLIProxyManager | (internal) | `class CLIProxyManager` |
| 224 | method | init | (internal) | `init()` |
| 263 | fn | restartProxyIfRunning | (private) | `private func restartProxyIfRunning()` |
| 294 | fn | loadLocalConfigSnapshot | (internal) | `func loadLocalConfigSnapshot() -> LocalProxyCon...` |
| 311 | fn | readLocalConfigContent | (private) | `private func readLocalConfigContent() -> String?` |
| 321 | fn | writePatchedConfig | (private) | `@discardableResult   private func writePatchedC...` |
| 337 | fn | updateTopLevelConfigValue | (private) | `@discardableResult   private func updateTopLeve...` |
| 344 | fn | updateNestedConfigValue | (private) | `@discardableResult   private func updateNestedC...` |
| 351 | fn | updateConfigPort | (private) | `private func updateConfigPort(_ newPort: UInt16)` |
| 355 | fn | loadUserPortFromConfigIfPresent | (private) | `private func loadUserPortFromConfigIfPresent()` |
| 364 | fn | updateProxyStatus | (private) | `private func updateProxyStatus(running: Bool? =...` |
| 376 | fn | configHostAllowsNetworkAccess | (private) | `private func configHostAllowsNetworkAccess() ->...` |
| 384 | fn | updateConfigHost | (private) | `private func updateConfigHost(_ host: String)` |
| 388 | fn | ensureApiKeyExistsInConfig | (private) | `private func ensureApiKeyExistsInConfig()` |
| 437 | fn | updateConfigAllowRemote | (internal) | `@discardableResult   func updateConfigAllowRemo...` |
| 442 | fn | updateConfigLogging | (internal) | `@discardableResult   func updateConfigLogging(e...` |
| 449 | fn | updateConfigRoutingStrategy | (internal) | `func updateConfigRoutingStrategy(_ strategy: St...` |
| 452 | fn | updateConfigSwitchProject | (internal) | `@discardableResult   func updateConfigSwitchPro...` |
| 457 | fn | updateConfigSwitchPreviewModel | (internal) | `@discardableResult   func updateConfigSwitchPre...` |
| 462 | fn | updateConfigRequestRetry | (internal) | `@discardableResult   func updateConfigRequestRe...` |
| 467 | fn | updateConfigMaxRetryInterval | (internal) | `@discardableResult   func updateConfigMaxRetryI...` |
| 472 | fn | updateConfigRequestLog | (internal) | `@discardableResult   func updateConfigRequestLo...` |
| 477 | fn | updateConfigDebug | (internal) | `@discardableResult   func updateConfigDebug(_ e...` |
| 482 | fn | updateConfigProxyURL | (internal) | `@discardableResult   func updateConfigProxyURL(...` |
| 525 | fn | applyBaseURLWorkaround | (internal) | `func applyBaseURLWorkaround()` |
| 554 | fn | removeBaseURLWorkaround | (internal) | `func removeBaseURLWorkaround()` |
| 596 | fn | ensureConfigExists | (private) | `private func ensureConfigExists()` |
| 637 | fn | prepareLaunchConfiguration | (private) | `private func prepareLaunchConfiguration() throw...` |
| 648 | fn | launchConfiguration | (private) | `private func launchConfiguration(from content: ...` |
| 665 | fn | reconcileRunningStateWithSystem | (internal) | `@discardableResult   func reconcileRunningState...` |
| 680 | fn | reconcileRunningStateSnapshotWithSystem | (internal) | `@discardableResult   func reconcileRunningState...` |
| 697 | fn | applyReconciledRunningState | (private) | `private func applyReconciledRunningState(_ isRu...` |
| 711 | fn | isCLIProxyProcessRunning | (private) | `private func isCLIProxyProcessRunning(userPort:...` |
| 721 | fn | isCLIProxyProcessRunningSnapshot | (private) | `private func isCLIProxyProcessRunningSnapshot(u...` |
| 789 | fn | resolveManagementKey | (private) | `private func resolveManagementKey(from content:...` |
| 803 | fn | extractManagementKey | (private) | `private func extractManagementKey(from content:...` |
| 829 | fn | isPlaintextManagementKey | (private) | `private func isPlaintextManagementKey(_ value: ...` |
| 851 | fn | quoteYAMLScalar | (private) | `private func quoteYAMLScalar(_ value: String) -...` |
| 963 | fn | replaceOrAppendTopLevelPort | (private) | `private func replaceOrAppendTopLevelPort(_ port...` |
| 978 | fn | replaceOrAppendManagementKey | (private) | `private func replaceOrAppendManagementKey(_ key...` |
| 1014 | fn | prepareAuthCommandConfig | (private) | `private func prepareAuthCommandConfig() throws ...` |
| 1022 | fn | syncSecretKeyInConfig | (private) | `private func syncSecretKeyInConfig()` |
| 1038 | fn | regenerateManagementKey | (internal) | `func regenerateManagementKey() async throws` |
| 1077 | fn | downloadAndInstallBinary | (internal) | `func downloadAndInstallBinary() async throws` |
| 1135 | fn | fetchLatestRelease | (private) | `private func fetchLatestRelease(source: ProxyBi...` |
| 1160 | fn | findCompatibleAsset | (private) | `private func findCompatibleAsset(in release: Re...` |
| 1182 | fn | downloadAsset | (private) | `private func downloadAsset(url: String) async t...` |
| 1201 | fn | extractAndInstall | (private) | `private func extractAndInstall(data: Data, asse...` |
| 1263 | fn | findBinaryInDirectory | (private) | `private func findBinaryInDirectory(_ directory:...` |
| 1296 | fn | start | (internal) | `func start(resetCrashRecoveryState: Bool = true...` |
| 1443 | fn | stop | (internal) | `func stop()` |
| 1502 | fn | stopAndWait | (internal) | `func stopAndWait() async` |
| 1550 | fn | startHealthMonitor | (private) | `private func startHealthMonitor()` |
| 1564 | fn | stopHealthMonitor | (private) | `private func stopHealthMonitor()` |
| 1569 | fn | markExpectedTermination | (private) | `private func markExpectedTermination(_ process:...` |
| 1574 | fn | cancelCrashRestart | (private) | `private func cancelCrashRestart()` |
| 1579 | fn | scheduleCrashRestart | (private) | `private func scheduleCrashRestart(exitCode: Int32)` |
| 1627 | fn | performHealthCheck | (private) | `private func performHealthCheck() async` |
| 1694 | fn | cleanupOrphanProcesses | (private) | `private func cleanupOrphanProcesses() async` |
| 1757 | fn | terminateAuthProcess | (internal) | `func terminateAuthProcess()` |
| 1765 | fn | toggle | (internal) | `func toggle() async throws` |
| 1773 | fn | copyEndpointToClipboard | (internal) | `func copyEndpointToClipboard()` |
| 1778 | fn | revealInFinder | (internal) | `func revealInFinder()` |
| 1785 | enum | ProxyError | (internal) | `enum ProxyError` |
| 1821 | enum | AuthCommand | (internal) | `enum AuthCommand` |
| 1859 | struct | AuthCommandResult | (internal) | `struct AuthCommandResult` |
| 1865 | mod | extension CLIProxyManager | (internal) | - |
| 1866 | fn | runAuthCommand | (internal) | `func runAuthCommand(_ command: AuthCommand) asy...` |
| 1910 | fn | appendOutput | (internal) | `func appendOutput(_ str: String)` |
| 1914 | fn | tryResume | (internal) | `func tryResume() -> Bool` |
| 1925 | fn | safeResume | (internal) | `@Sendable func safeResume(_ result: AuthCommand...` |
| 2028 | mod | extension CLIProxyManager | (internal) | - |
| 2061 | fn | isLegacyAuthWarningNeeded | (internal) | `func isLegacyAuthWarningNeeded(for provider: AI...` |
| 2066 | fn | sourceInstallHint | (internal) | `func sourceInstallHint(for source: ProxyBinaryS...` |
| 2070 | fn | confirmBinarySourceSelection | (internal) | `func confirmBinarySourceSelection(_ source: Pro...` |
| 2080 | fn | isSourceInstalled | (internal) | `func isSourceInstalled(_ source: ProxyBinarySou...` |
| 2124 | fn | checkForUpgrade | (internal) | `func checkForUpgrade() async` |
| 2181 | fn | saveInstalledVersion | (private) | `private func saveInstalledVersion(_ version: St...` |
| 2186 | fn | fetchAvailableVersions | (internal) | `func fetchAvailableVersions(limit: Int = 10) as...` |
| 2198 | fn | fetchAvailableUpstreamVersions | (private) | `private func fetchAvailableUpstreamVersions(lim...` |
| 2225 | fn | versionInfo | (internal) | `func versionInfo(from release: GitHubRelease) -...` |
| 2231 | fn | fetchGitHubRelease | (private) | `private func fetchGitHubRelease(tag: String, so...` |
| 2257 | fn | findCompatibleAsset | (private) | `private func findCompatibleAsset(from release: ...` |
| 2287 | fn | performManagedUpgrade | (internal) | `func performManagedUpgrade(to version: ProxyVer...` |
| 2334 | fn | downloadAndInstallVersion | (private) | `private func downloadAndInstallVersion(_ versio...` |
| 2390 | fn | rollback | (internal) | `func rollback() async throws` |
| 2427 | fn | isNewerVersion | (private) | `private func isNewerVersion(_ newer: String, th...` |
| 2430 | fn | parseVersion | (internal) | `func parseVersion(_ version: String) -> [Int]` |
| 2462 | fn | plusLocalVersionInfo | (private) | `private func plusLocalVersionInfo() -> ProxyVer...` |
| 2476 | fn | installLocalPlusBinary | (private) | `private func installLocalPlusBinary() async thr...` |
| 2483 | fn | findPreviousVersion | (private) | `private func findPreviousVersion() -> String?` |
| 2496 | fn | migrateToVersionedStorage | (internal) | `func migrateToVersionedStorage() async throws` |
| 2522 | fn | initializeSelectedBinarySourceIfNeeded | (private) | `private func initializeSelectedBinarySourceIfNe...` |
| 2532 | fn | defaultBinarySource | (private) | `private func defaultBinarySource() -> ProxyBina...` |
| 2539 | fn | migrateLegacyVersionedStorageIfNeeded | (private) | `private func migrateLegacyVersionedStorageIfNee...` |
| 2567 | fn | resolveBundledPlusBinaryPath | (private) | `private func resolveBundledPlusBinaryPath() -> ...` |
| 2572 | fn | firstExistingRegularFile | (internal) | `func firstExistingRegularFile(in candidates: [U...` |

## Memory Markers

### 🟢 `NOTE` (line 250)

> Bridge mode default is registered in AppDelegate.applicationDidFinishLaunching()

### 🟢 `NOTE` (line 2164)

> Notification is handled by AtomFeedUpdateService polling

