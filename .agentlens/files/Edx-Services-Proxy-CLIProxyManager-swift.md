# Edx/Services/Proxy/CLIProxyManager.swift

[← Back to Module](../modules/root/MODULE.md) | [← Back to INDEX](../INDEX.md)

## Overview

- **Lines:** 2351
- **Language:** Swift
- **Symbols:** 80
- **Public symbols:** 0

## Symbol Table

| Line | Kind | Name | Visibility | Signature |
| ---- | ---- | ---- | ---------- | --------- |
| 9 | class | CLIProxyManager | (internal) | `class CLIProxyManager` |
| 213 | method | init | (internal) | `init()` |
| 256 | fn | restartProxyIfRunning | (private) | `private func restartProxyIfRunning()` |
| 274 | fn | updateConfigValue | (private) | `private func updateConfigValue(pattern: String,...` |
| 294 | fn | updateConfigPort | (private) | `private func updateConfigPort(_ newPort: UInt16)` |
| 298 | fn | updateConfigHost | (private) | `private func updateConfigHost(_ host: String)` |
| 302 | fn | ensureApiKeyExistsInConfig | (private) | `private func ensureApiKeyExistsInConfig()` |
| 351 | fn | updateConfigAllowRemote | (internal) | `func updateConfigAllowRemote(_ enabled: Bool)` |
| 355 | fn | updateConfigLogging | (internal) | `func updateConfigLogging(enabled: Bool)` |
| 363 | fn | updateConfigRoutingStrategy | (internal) | `func updateConfigRoutingStrategy(_ strategy: St...` |
| 368 | fn | updateConfigProxyURL | (internal) | `func updateConfigProxyURL(_ url: String?)` |
| 396 | fn | applyBaseURLWorkaround | (internal) | `func applyBaseURLWorkaround()` |
| 425 | fn | removeBaseURLWorkaround | (internal) | `func removeBaseURLWorkaround()` |
| 467 | fn | ensureConfigExists | (private) | `private func ensureConfigExists()` |
| 501 | fn | syncSecretKeyInConfig | (private) | `private func syncSecretKeyInConfig()` |
| 517 | fn | regenerateManagementKey | (internal) | `func regenerateManagementKey() async throws` |
| 559 | fn | syncProxyURLInConfig | (private) | `private func syncProxyURLInConfig()` |
| 576 | fn | syncCustomProvidersToConfig | (private) | `private func syncCustomProvidersToConfig()` |
| 589 | fn | downloadAndInstallBinary | (internal) | `func downloadAndInstallBinary() async throws` |
| 647 | fn | fetchLatestRelease | (private) | `private func fetchLatestRelease(source: ProxyBi...` |
| 672 | fn | findCompatibleAsset | (private) | `private func findCompatibleAsset(in release: Re...` |
| 694 | fn | downloadAsset | (private) | `private func downloadAsset(url: String) async t...` |
| 713 | fn | extractAndInstall | (private) | `private func extractAndInstall(data: Data, asse...` |
| 775 | fn | findBinaryInDirectory | (private) | `private func findBinaryInDirectory(_ directory:...` |
| 808 | fn | start | (internal) | `func start(resetCrashRecoveryState: Bool = true...` |
| 957 | fn | stop | (internal) | `func stop()` |
| 1011 | fn | stopAndWait | (internal) | `func stopAndWait() async` |
| 1054 | fn | startHealthMonitor | (private) | `private func startHealthMonitor()` |
| 1068 | fn | stopHealthMonitor | (private) | `private func stopHealthMonitor()` |
| 1073 | fn | markExpectedTermination | (private) | `private func markExpectedTermination(_ process:...` |
| 1078 | fn | cancelCrashRestart | (private) | `private func cancelCrashRestart()` |
| 1083 | fn | scheduleCrashRestart | (private) | `private func scheduleCrashRestart(exitCode: Int32)` |
| 1131 | fn | performHealthCheck | (private) | `private func performHealthCheck() async` |
| 1198 | fn | cleanupOrphanProcesses | (private) | `private func cleanupOrphanProcesses() async` |
| 1261 | fn | terminateAuthProcess | (internal) | `func terminateAuthProcess()` |
| 1267 | fn | toggle | (internal) | `func toggle() async throws` |
| 1275 | fn | copyEndpointToClipboard | (internal) | `func copyEndpointToClipboard()` |
| 1280 | fn | revealInFinder | (internal) | `func revealInFinder()` |
| 1287 | enum | ProxyError | (internal) | `enum ProxyError` |
| 1320 | enum | AuthCommand | (internal) | `enum AuthCommand` |
| 1358 | struct | AuthCommandResult | (internal) | `struct AuthCommandResult` |
| 1364 | mod | extension CLIProxyManager | (internal) | - |
| 1365 | fn | runAuthCommand | (internal) | `func runAuthCommand(_ command: AuthCommand) asy...` |
| 1397 | fn | appendOutput | (internal) | `func appendOutput(_ str: String)` |
| 1401 | fn | tryResume | (internal) | `func tryResume() -> Bool` |
| 1412 | fn | safeResume | (internal) | `@Sendable func safeResume(_ result: AuthCommand...` |
| 1512 | mod | extension CLIProxyManager | (internal) | - |
| 1545 | fn | isLegacyAuthWarningNeeded | (internal) | `func isLegacyAuthWarningNeeded(for provider: AI...` |
| 1550 | fn | sourceInstallHint | (internal) | `func sourceInstallHint(for source: ProxyBinaryS...` |
| 1554 | fn | confirmBinarySourceSelection | (internal) | `func confirmBinarySourceSelection(_ source: Pro...` |
| 1564 | fn | isSourceInstalled | (internal) | `func isSourceInstalled(_ source: ProxyBinarySou...` |
| 1608 | fn | checkForUpgrade | (internal) | `func checkForUpgrade() async` |
| 1665 | fn | saveInstalledVersion | (private) | `private func saveInstalledVersion(_ version: St...` |
| 1670 | fn | fetchAvailableVersions | (internal) | `func fetchAvailableVersions(limit: Int = 10) as...` |
| 1682 | fn | fetchAvailableUpstreamVersions | (private) | `private func fetchAvailableUpstreamVersions(lim...` |
| 1709 | fn | versionInfo | (internal) | `func versionInfo(from release: GitHubRelease) -...` |
| 1715 | fn | fetchGitHubRelease | (private) | `private func fetchGitHubRelease(tag: String, so...` |
| 1741 | fn | findCompatibleAsset | (private) | `private func findCompatibleAsset(from release: ...` |
| 1771 | fn | performManagedUpgrade | (internal) | `func performManagedUpgrade(to version: ProxyVer...` |
| 1833 | fn | downloadAndInstallVersion | (private) | `private func downloadAndInstallVersion(_ versio...` |
| 1889 | fn | startDryRun | (private) | `private func startDryRun(version: String, sourc...` |
| 1963 | fn | promote | (private) | `private func promote(version: String, source: P...` |
| 1999 | fn | rollback | (internal) | `func rollback() async throws` |
| 2032 | fn | stopTestProxy | (private) | `private func stopTestProxy() async` |
| 2063 | fn | stopTestProxySync | (private) | `private func stopTestProxySync()` |
| 2091 | fn | findUnusedPort | (private) | `private func findUnusedPort() throws -> UInt16` |
| 2101 | fn | isPortInUse | (private) | `private func isPortInUse(_ port: UInt16) -> Bool` |
| 2120 | fn | createTestConfig | (private) | `private func createTestConfig(port: UInt16, man...` |
| 2148 | fn | cleanupTestConfig | (private) | `private func cleanupTestConfig(_ configPath: St...` |
| 2156 | fn | isNewerVersion | (private) | `private func isNewerVersion(_ newer: String, th...` |
| 2159 | fn | parseVersion | (internal) | `func parseVersion(_ version: String) -> [Int]` |
| 2191 | fn | plusLocalVersionInfo | (private) | `private func plusLocalVersionInfo() -> ProxyVer...` |
| 2205 | fn | installLocalPlusBinary | (private) | `private func installLocalPlusBinary() async thr...` |
| 2212 | fn | findPreviousVersion | (private) | `private func findPreviousVersion() -> String?` |
| 2225 | fn | migrateToVersionedStorage | (internal) | `func migrateToVersionedStorage() async throws` |
| 2251 | fn | initializeSelectedBinarySourceIfNeeded | (private) | `private func initializeSelectedBinarySourceIfNe...` |
| 2261 | fn | defaultBinarySource | (private) | `private func defaultBinarySource() -> ProxyBina...` |
| 2268 | fn | migrateLegacyVersionedStorageIfNeeded | (private) | `private func migrateLegacyVersionedStorageIfNee...` |
| 2296 | fn | resolveBundledPlusBinaryPath | (private) | `private func resolveBundledPlusBinaryPath() -> ...` |
| 2301 | fn | firstExistingRegularFile | (internal) | `func firstExistingRegularFile(in candidates: [U...` |

## Memory Markers

### 🟢 `NOTE` (line 244)

> Bridge mode default is registered in AppDelegate.applicationDidFinishLaunching()

### 🟢 `NOTE` (line 362)

> Changes take effect after proxy restart (CLIProxyAPI does not support live routing API)

### 🟢 `NOTE` (line 1648)

> Notification is handled by AtomFeedUpdateService polling

