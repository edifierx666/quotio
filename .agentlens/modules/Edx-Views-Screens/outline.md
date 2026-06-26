# Outline

[← Back to MODULE](MODULE.md) | [← Back to INDEX](../../INDEX.md)

Symbol maps for 6 large files in this module.

## Edx/Views/Screens/DashboardScreen.swift (1014 lines)

| Line | Kind | Name | Visibility |
| ---- | ---- | ---- | ---------- |
| 9 | struct | DashboardScreen | (internal) |
| 572 | fn | handleStepAction | (private) |
| 583 | fn | showProviderPicker | (private) |
| 607 | fn | showAgentPicker | (private) |
| 808 | struct | GettingStartedStep | (internal) |
| 817 | struct | GettingStartedStepRow | (internal) |
| 872 | struct | KPICard | (internal) |
| 900 | struct | ProviderChip | (internal) |
| 924 | struct | FlowLayout | (internal) |
| 938 | fn | layout | (private) |
| 966 | struct | QuotaProviderRow | (internal) |

## Edx/Views/Screens/FallbackScreen.swift (558 lines)

| Line | Kind | Name | Visibility |
| ---- | ---- | ---- | ---------- |
| 8 | struct | FallbackScreen | (internal) |
| 113 | fn | loadModelsIfNeeded | (private) |
| 341 | struct | VirtualModelsEmptyState | (internal) |
| 383 | struct | VirtualModelRow | (internal) |
| 504 | struct | FallbackEntryRow | (internal) |

## Edx/Views/Screens/LogsScreen.swift (541 lines)

| Line | Kind | Name | Visibility |
| ---- | ---- | ---- | ---------- |
| 8 | struct | LogsScreen | (internal) |
| 301 | struct | RequestRow | (internal) |
| 475 | fn | attemptOutcomeLabel | (private) |
| 486 | fn | attemptOutcomeColor | (private) |
| 501 | struct | StatItem | (internal) |
| 518 | struct | LogRow | (internal) |

## Edx/Views/Screens/ProvidersScreen.swift (1058 lines)

| Line | Kind | Name | Visibility |
| ---- | ---- | ---- | ---------- |
| 16 | struct | ProvidersScreen | (internal) |
| 376 | fn | handleAddProvider | (private) |
| 394 | fn | deleteAccount | (private) |
| 424 | fn | toggleAccountDisabled | (private) |
| 434 | fn | handleEditGlmAccount | (private) |
| 441 | fn | handleEditWarpAccount | (private) |
| 449 | fn | syncCustomProvidersToConfig | (private) |
| 459 | struct | CustomProviderRow | (internal) |
| 560 | struct | MenuBarBadge | (internal) |
| 583 | class | TooltipWindow | (private) |
| 595 | method | init | (private) |
| 625 | fn | show | (internal) |
| 654 | fn | hide | (internal) |
| 660 | class | TooltipTrackingView | (private) |
| 662 | fn | updateTrackingAreas | (internal) |
| 673 | fn | mouseEntered | (internal) |
| 677 | fn | mouseExited | (internal) |
| 681 | fn | hitTest | (internal) |
| 687 | struct | NativeTooltipView | (private) |
| 689 | fn | makeNSView | (internal) |
| 695 | fn | updateNSView | (internal) |
| 701 | mod | extension View | (private) |
| 702 | fn | nativeTooltip | (internal) |
| 709 | struct | MenuBarHintView | (internal) |
| 724 | struct | OAuthSheet | (internal) |
| 865 | struct | OAuthStatusView | (private) |
| 1037 | enum | CustomProviderSheetMode | (internal) |

## Edx/Views/Screens/QuotaScreen.swift (1644 lines)

| Line | Kind | Name | Visibility |
| ---- | ---- | ---- | ---------- |
| 8 | struct | QuotaScreen | (internal) |
| 37 | fn | accountCount | (private) |
| 54 | fn | lowestQuotaPercent | (private) |
| 213 | struct | QuotaDisplayHelper | (private) |
| 215 | fn | statusColor | (internal) |
| 231 | fn | displayPercent | (internal) |
| 240 | struct | ProviderSegmentButton | (private) |
| 318 | struct | QuotaStatusDot | (private) |
| 337 | struct | ProviderQuotaView | (private) |
| 436 | struct | AccountInfo | (private) |
| 448 | struct | AccountQuotaCardV2 | (private) |
| 860 | fn | standardContentByStyle | (private) |
| 888 | struct | PlanBadgeV2Compact | (private) |
| 942 | struct | PlanBadgeV2 | (private) |
| 997 | struct | SubscriptionBadgeV2 | (private) |
| 1038 | struct | AntigravityDisplayGroup | (private) |
| 1048 | struct | AntigravityGroupRow | (private) |
| 1125 | struct | AntigravityLowestBarLayout | (private) |
| 1144 | fn | displayPercent | (private) |
| 1206 | struct | AntigravityRingLayout | (private) |
| 1218 | fn | displayPercent | (private) |
| 1247 | struct | StandardLowestBarLayout | (private) |
| 1266 | fn | displayPercent | (private) |
| 1339 | struct | StandardRingLayout | (private) |
| 1351 | fn | displayPercent | (private) |
| 1386 | struct | AntigravityModelsDetailSheet | (private) |
| 1455 | struct | ModelDetailCard | (private) |
| 1522 | struct | UsageRowV2 | (private) |
| 1610 | struct | QuotaLoadingView | (private) |

## Edx/Views/Screens/SettingsScreen.swift (2954 lines)

| Line | Kind | Name | Visibility |
| ---- | ---- | ---- | ---------- |
| 9 | struct | SettingsScreen | (internal) |
| 111 | struct | OperatingModeSection | (internal) |
| 176 | fn | handleModeSelection | (private) |
| 195 | fn | switchToMode | (private) |
| 210 | struct | RemoteServerSection | (internal) |
| 330 | fn | saveRemoteConfig | (private) |
| 338 | fn | reconnect | (private) |
| 353 | struct | UnifiedProxySettingsSection | (internal) |
| 573 | fn | loadConfig | (private) |
| 620 | fn | saveProxyURL | (private) |
| 638 | fn | saveRoutingStrategy | (private) |
| 647 | fn | saveSwitchProject | (private) |
| 656 | fn | saveSwitchPreviewModel | (private) |
| 665 | fn | saveRequestRetry | (private) |
| 674 | fn | saveMaxRetryInterval | (private) |
| 683 | fn | saveLoggingToFile | (private) |
| 692 | fn | saveRequestLog | (private) |
| 701 | fn | saveDebugMode | (private) |
| 714 | struct | LocalProxyServerSection | (internal) |
| 788 | struct | NetworkAccessSection | (internal) |
| 822 | struct | LocalPathsSection | (internal) |
| 846 | struct | PathLabel | (internal) |
| 870 | struct | NotificationSettingsSection | (internal) |
| 940 | struct | QuotaDisplaySettingsSection | (internal) |
| 982 | struct | RefreshCadenceSettingsSection | (internal) |
| 1021 | struct | UpdateSettingsSection | (internal) |
| 1063 | struct | ProxyUpdateSettingsSection | (internal) |
| 1218 | fn | checkForUpdate | (private) |
| 1232 | fn | performUpgrade | (private) |
| 1251 | struct | ProxyVersionManagerSheet | (internal) |
| 1428 | fn | sectionHeader | (private) |
| 1443 | fn | isVersionInstalled | (private) |
| 1447 | fn | refreshInstalledVersions | (private) |
| 1451 | fn | loadReleases | (private) |
| 1465 | fn | installVersion | (private) |
| 1478 | fn | performInstall | (private) |
| 1494 | fn | activateVersion | (private) |
| 1512 | fn | deleteVersion | (private) |
| 1523 | struct | NamespacedInstalledVersionItem | (private) |
| 1528 | struct | NamespacedAvailableVersionItem | (private) |
| 1535 | struct | InstalledVersionRow | (private) |
| 1593 | struct | AvailableVersionRow | (private) |
| 1670 | struct | MenuBarSettingsSection | (internal) |
| 1811 | struct | AppearanceSettingsSection | (internal) |
| 1840 | struct | PrivacySettingsSection | (internal) |
| 1862 | struct | GeneralSettingsTab | (internal) |
| 1901 | struct | AboutTab | (internal) |
| 1928 | struct | AboutScreen | (internal) |
| 2143 | struct | VersionBadge | (internal) |
| 2195 | struct | AboutUpdateCard | (internal) |
| 2289 | struct | AboutProxyUpdateCard | (internal) |
| 2501 | fn | checkForUpdate | (private) |
| 2515 | fn | performUpgrade | (private) |
| 2532 | struct | ProxyBinarySourceOptionBlock | (private) |
| 2571 | struct | ProxyBinarySourceSelectionSheet | (internal) |
| 2638 | fn | cardHeader | (private) |
| 2652 | struct | LinkCard | (internal) |
| 2739 | struct | ManagementKeyRow | (internal) |
| 2833 | struct | LaunchAtLoginToggle | (internal) |
| 2891 | struct | UsageDisplaySettingsSection | (internal) |

