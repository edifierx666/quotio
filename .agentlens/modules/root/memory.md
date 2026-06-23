# Memory

[← Back to MODULE](MODULE.md) | [← Back to INDEX](../../INDEX.md)

## Summary

| High 🔴 | Medium 🟡 | Low 🟢 |
| 1 | 0 | 13 |

## 🔴 High Priority

### `WARNING` (Quotio/Services/LaunchAtLoginManager.swift:97)

> if app is not in /Applications (registration may fail or be non-persistent)

## 🟢 Low Priority

### `NOTE` (Quotio/Services/AgentDetectionService.swift:16)

> Only checks file existence (metadata), does NOT read file content

### `NOTE` (Quotio/Services/AgentDetectionService.swift:92)

> May not work in GUI apps due to limited PATH inheritance

### `NOTE` (Quotio/Services/AgentDetectionService.swift:98)

> Only checks file existence (metadata), does NOT read file content

### `NOTE` (Quotio/Services/CLIExecutor.swift:33)

> Only checks file existence (metadata), does NOT read file content

### `NOTE` (Quotio/Services/Proxy/CLIProxyManager.swift:250)

> Bridge mode default is registered in AppDelegate.applicationDidFinishLaunching()

### `NOTE` (Quotio/Services/Proxy/CLIProxyManager.swift:2164)

> Notification is handled by AtomFeedUpdateService polling

### `NOTE` (Quotio/ViewModels/AgentSetupViewModel.swift:452)

> Actual fallback resolution happens at request time in ProxyBridge

### `NOTE` (Quotio/ViewModels/QuotaViewModel.swift:343)

> Cursor and Trae are NOT auto-refreshed - user must use "Scan for IDEs" (issue #29)

### `NOTE` (Quotio/ViewModels/QuotaViewModel.swift:351)

> Cursor and Trae removed from auto-refresh to address privacy concerns (issue #29)

### `NOTE` (Quotio/ViewModels/QuotaViewModel.swift:1205)

> Cursor and Trae removed from auto-refresh (issue #29)

### `NOTE` (Quotio/ViewModels/QuotaViewModel.swift:1232)

> Cursor and Trae require explicit user scan (issue #29)

### `NOTE` (Quotio/ViewModels/QuotaViewModel.swift:1242)

> Cursor and Trae removed - require explicit scan (issue #29)

### `NOTE` (Quotio/ViewModels/QuotaViewModel.swift:1297)

> Don't call detectActiveAccount() here - already set by switch operation

