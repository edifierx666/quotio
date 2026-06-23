# Outline

[← Back to MODULE](MODULE.md) | [← Back to INDEX](../../INDEX.md)

Symbol maps for 6 large files in this module.

## Quotio/Views/Screens/DashboardScreen.swift (1091 lines)

| Line | Kind | Name | Visibility |
| ---- | ---- | ---- | ---------- |
| 9 | struct | DashboardScreen | (internal) |
| 573 | fn | handleStepAction | (private) |
| 584 | fn | showProviderPicker | (private) |
| 608 | fn | showAgentPicker | (private) |
| 746 | fn | dashboardAddressRow | (private) |
| 784 | fn | copyToClipboard | (private) |
| 789 | fn | openManagementPage | (private) |
| 885 | struct | GettingStartedStep | (internal) |
| 894 | struct | GettingStartedStepRow | (internal) |
| 949 | struct | KPICard | (internal) |
| 977 | struct | ProviderChip | (internal) |
| 1001 | struct | FlowLayout | (internal) |
| 1015 | fn | layout | (private) |
| 1043 | struct | QuotaProviderRow | (internal) |

## Quotio/Views/Screens/FallbackScreen.swift (558 lines)

| Line | Kind | Name | Visibility |
| ---- | ---- | ---- | ---------- |
| 8 | struct | FallbackScreen | (internal) |
| 113 | fn | loadModelsIfNeeded | (private) |
| 341 | struct | VirtualModelsEmptyState | (internal) |
| 383 | struct | VirtualModelRow | (internal) |
| 504 | struct | FallbackEntryRow | (internal) |

## Quotio/Views/Screens/LogsScreen.swift (541 lines)

| Line | Kind | Name | Visibility |
| ---- | ---- | ---- | ---------- |
| 8 | struct | LogsScreen | (internal) |
| 301 | struct | RequestRow | (internal) |
| 475 | fn | attemptOutcomeLabel | (private) |
| 486 | fn | attemptOutcomeColor | (private) |
| 501 | struct | StatItem | (internal) |
| 518 | struct | LogRow | (internal) |

## Quotio/Views/Screens/ProvidersScreen.swift (1058 lines)

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

## Quotio/Views/Screens/QuotaScreen.swift (1644 lines)

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

## Quotio/Views/Screens/SettingsScreen.swift (2965 lines)

| Line | Kind | Name | Visibility |
| ---- | ---- | ---- | ---------- |
| 9 | struct | SettingsScreen | (internal) |
| 87 | struct | OperatingModeSection | (internal) |
| 152 | fn | handleModeSelection | (private) |
| 171 | fn | switchToMode | (private) |
| 186 | struct | RemoteServerSection | (internal) |
| 306 | fn | saveRemoteConfig | (private) |
| 314 | fn | reconnect | (private) |
| 329 | struct | UnifiedProxySettingsSection | (internal) |
| 547 | fn | loadConfig | (private) |
| 616 | fn | saveProxyURL | (private) |
| 645 | fn | saveRoutingStrategy | (private) |
| 662 | fn | saveSwitchProject | (private) |
| 679 | fn | saveSwitchPreviewModel | (private) |
| 696 | fn | saveRequestRetry | (private) |
| 713 | fn | saveMaxRetryInterval | (private) |
| 730 | fn | saveLoggingToFile | (private) |
| 747 | fn | saveRequestLog | (private) |
| 764 | fn | saveDebugMode | (private) |
| 785 | struct | LocalProxyServerSection | (internal) |
| 859 | struct | NetworkAccessSection | (internal) |
| 893 | struct | LocalPathsSection | (internal) |
| 932 | struct | PathLabel | (internal) |
| 975 | fn | copyPath | (private) |
| 981 | fn | revealInFinder | (private) |
| 985 | fn | openFile | (private) |
| 991 | struct | NotificationSettingsSection | (internal) |
| 1061 | struct | QuotaDisplaySettingsSection | (internal) |
| 1103 | struct | RefreshCadenceSettingsSection | (internal) |
| 1142 | struct | UpdateSettingsSection | (internal) |
| 1184 | struct | ProxyUpdateSettingsSection | (internal) |
| 1339 | fn | checkForUpdate | (private) |
| 1353 | fn | performUpgrade | (private) |
| 1372 | struct | ProxyVersionManagerSheet | (internal) |
| 1549 | fn | sectionHeader | (private) |
| 1564 | fn | isVersionInstalled | (private) |
| 1568 | fn | refreshInstalledVersions | (private) |
| 1572 | fn | loadReleases | (private) |
| 1586 | fn | installVersion | (private) |
| 1599 | fn | performInstall | (private) |
| 1615 | fn | activateVersion | (private) |
| 1633 | fn | deleteVersion | (private) |
| 1644 | struct | NamespacedInstalledVersionItem | (private) |
| 1649 | struct | NamespacedAvailableVersionItem | (private) |
| 1656 | struct | InstalledVersionRow | (private) |
| 1714 | struct | AvailableVersionRow | (private) |
| 1791 | struct | MenuBarSettingsSection | (internal) |
| 1822 | struct | AppearanceSettingsSection | (internal) |
| 1851 | struct | PrivacySettingsSection | (internal) |
| 1873 | struct | GeneralSettingsTab | (internal) |
| 1912 | struct | AboutTab | (internal) |
| 1939 | struct | AboutScreen | (internal) |
| 2154 | struct | VersionBadge | (internal) |
| 2206 | struct | AboutUpdateCard | (internal) |
| 2300 | struct | AboutProxyUpdateCard | (internal) |
| 2512 | fn | checkForUpdate | (private) |
| 2526 | fn | performUpgrade | (private) |
| 2543 | struct | ProxyBinarySourceOptionBlock | (private) |
| 2582 | struct | ProxyBinarySourceSelectionSheet | (internal) |
| 2649 | fn | cardHeader | (private) |
| 2663 | struct | LinkCard | (internal) |
| 2750 | struct | ManagementKeyRow | (internal) |
| 2844 | struct | LaunchAtLoginToggle | (internal) |
| 2902 | struct | UsageDisplaySettingsSection | (internal) |

