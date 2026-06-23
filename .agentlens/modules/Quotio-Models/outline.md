# Outline

[← Back to MODULE](MODULE.md) | [← Back to INDEX](../../INDEX.md)

Symbol maps for 3 large files in this module.

## Quotio/Models/CustomProviderModels.swift (546 lines)

| Line | Kind | Name | Visibility |
| ---- | ---- | ---- | ---------- |
| 14 | enum | CustomProviderType | (internal) |
| 148 | struct | CustomAPIKeyEntry | (internal) |
| 179 | struct | ModelMapping | (internal) |
| 206 | struct | CustomHeader | (internal) |
| 225 | struct | CustomProvider | (internal) |
| 277 | method | init | (internal) |
| 293 | fn | encode | (internal) |
| 311 | fn | validate | (internal) |
| 349 | mod | extension CustomProvider | (internal) |
| 351 | fn | toYAMLBlock | (internal) |
| 365 | fn | generateOpenAICompatibilityYAML | (private) |
| 394 | fn | generateClaudeCompatibilityYAML | (private) |
| 423 | fn | generateGeminiCompatibilityYAML | (private) |
| 451 | fn | generateCodexCompatibilityYAML | (private) |
| 468 | fn | generateGlmCompatibilityYAML | (private) |
| 498 | fn | toYAMLSections | (internal) |

## Quotio/Models/MenuBarSettings.swift (630 lines)

| Line | Kind | Name | Visibility |
| ---- | ---- | ---- | ---------- |
| 13 | mod | extension String | (internal) |
| 17 | fn | masked | (internal) |
| 38 | fn | masked | (internal) |
| 46 | struct | MenuBarQuotaItem | (internal) |
| 70 | enum | AppearanceMode | (internal) |
| 97 | class | AppearanceManager | (internal) |
| 112 | method | init | (private) |
| 119 | fn | applyAppearance | (internal) |
| 134 | enum | MenuBarColorMode | (internal) |
| 151 | enum | QuotaDisplayMode | (internal) |
| 165 | fn | displayValue | (internal) |
| 183 | enum | QuotaDisplayStyle | (internal) |
| 210 | enum | RefreshCadence | (internal) |
| 253 | enum | TotalUsageMode | (internal) |
| 270 | enum | ModelAggregationMode | (internal) |
| 286 | mod | extension MenuBarSettingsManager | (internal) |
| 334 | fn | calculateTotalUsagePercent | (internal) |
| 359 | fn | aggregateModelPercentages | (internal) |
| 376 | class | RefreshSettingsManager | (internal) |
| 394 | method | init | (private) |
| 404 | struct | MenuBarQuotaDisplayItem | (internal) |
| 423 | class | MenuBarSettingsManager | (internal) |
| 515 | method | init | (private) |
| 551 | fn | saveSelectedItems | (private) |
| 557 | fn | loadSelectedItems | (private) |
| 565 | fn | addItem | (internal) |
| 579 | fn | removeItem | (internal) |
| 585 | fn | isSelected | (internal) |
| 590 | fn | toggleItem | (internal) |
| 600 | fn | pruneInvalidItems | (internal) |
| 604 | fn | autoSelectNewAccounts | (internal) |
| 619 | fn | enforceMaxItems | (private) |
| 626 | fn | clampedMenuBarMax | (private) |

## Quotio/Models/Models.swift (658 lines)

| Line | Kind | Name | Visibility |
| ---- | ---- | ---- | ---------- |
| 244 | mod | extension String | (internal) |
| 354 | fn | hash | (internal) |
| 545 | method | init | (internal) |
| 562 | mod | extension Int | (internal) |
| 608 | fn | validate | (internal) |
| 648 | fn | sanitize | (internal) |

