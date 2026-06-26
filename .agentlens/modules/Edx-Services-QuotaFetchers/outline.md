# Outline

[← Back to MODULE](MODULE.md) | [← Back to INDEX](../../INDEX.md)

Symbol maps for 2 large files in this module.

## Edx/Services/QuotaFetchers/GeminiCLIQuotaFetcher.swift (549 lines)

| Line | Kind | Name | Visibility |
| ---- | ---- | ---- | ---------- |
| 55 | class | GeminiCLIQuotaFetcher | (internal) |
| 121 | fn | updateProxyConfiguration | (internal) |
| 126 | fn | isInstalled | (internal) |
| 131 | fn | isAuthFilePresent | (internal) |
| 137 | fn | readAuthFile | (internal) |
| 148 | fn | readAccountsFile | (internal) |
| 159 | fn | decodeJWT | (internal) |
| 186 | fn | getAccountInfo | (internal) |
| 215 | fn | fetchAsProviderQuota | (internal) |
| 249 | fn | fetchAsProviderQuota | (internal) |
| 272 | fn | fetchQuota | (private) |
| 301 | fn | fetchPlanType | (private) |
| 333 | fn | parseBuckets | (private) |
| 368 | fn | buildModelQuotas | (private) |
| 430 | fn | resolveProjectId | (private) |
| 438 | fn | extractProjectId | (private) |
| 462 | fn | resolveTierLabel | (private) |
| 477 | fn | parseJSON | (private) |
| 485 | fn | jsonString | (private) |
| 490 | fn | stringValue | (private) |
| 501 | fn | numberValue | (private) |
| 515 | fn | isIgnoredGeminiModel | (private) |
| 519 | fn | minNullable | (private) |
| 525 | fn | pickEarlierResetTime | (private) |
| 543 | fn | groupId | (private) |

## Edx/Services/QuotaFetchers/KiroQuotaFetcher.swift (677 lines)

| Line | Kind | Name | Visibility |
| ---- | ---- | ---- | ---------- |
| 64 | class | KiroQuotaFetcher | (internal) |
| 70 | fn | socialTokenEndpoint | (private) |
| 75 | fn | idcTokenEndpoint | (private) |
| 80 | fn | usageEndpoint | (private) |
| 85 | fn | extractRegionFromProfileArn | (private) |
| 99 | fn | machineId | (private) |
| 132 | fn | kiroUserAgent | (private) |
| 137 | fn | kiroAmzUserAgent | (private) |
| 148 | method | init | (internal) |
| 155 | fn | updateProxyConfiguration | (internal) |
| 161 | fn | fetchAllQuotas | (internal) |
| 194 | fn | refreshAllTokensIfNeeded | (internal) |
| 221 | fn | shouldRefreshToken | (private) |
| 255 | fn | fetchQuota | (private) |
| 293 | fn | parseExpiryDate | (private) |
| 309 | fn | fetchUsageAPI | (private) |
| 397 | fn | refreshTokenWithExpiry | (private) |
| 413 | fn | refreshSocialTokenWithExpiry | (private) |
| 462 | fn | refreshIdCTokenWithExpiry | (private) |
| 534 | fn | syncToKiroIDEAuthFile | (private) |
| 566 | fn | persistRefreshedToken | (private) |
| 599 | fn | convertToQuotaData | (private) |

