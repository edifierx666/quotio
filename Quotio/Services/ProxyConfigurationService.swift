//
//  ProxyConfigurationService.swift
//  Edx
//
//  Created by Antigravity on 2026/01/11.
//

import Foundation
import Observation

extension Notification.Name {
    static let quotioLocalProxyConfigDidChange = Notification.Name("quotioLocalProxyConfigDidChange")
}

@MainActor
@Observable
final class ProxyConfigurationService {
    static let shared = ProxyConfigurationService()

    /// Current upstream proxy URL (validated and sanitized)
    var upstreamProxyURL: String? {
        Self.readProxyURLFromLocalConfig()
    }

    /// Create a URLSessionConfiguration with proxy settings applied
    func createProxiedConfiguration(timeout: TimeInterval = 15) -> URLSessionConfiguration {
        Self.createProxiedConfigurationStatic(timeout: timeout)
    }
    
    /// Static nonisolated method to create proxied configuration
    /// Can be called from any actor context
    nonisolated static func createProxiedConfigurationStatic(timeout: TimeInterval = 15) -> URLSessionConfiguration {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout

        if let proxyURLString = readProxyURLFromLocalConfig(),
           let url = URL(string: proxyURLString) {
            config.connectionProxyDictionary = proxyDictionary(from: url)
        }

        return config
    }

    nonisolated static func readProxyURLFromLocalConfig() -> String? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        let configURL = appSupport
            .appendingPathComponent("Edx")
            .appendingPathComponent("config.yaml")

        guard let content = try? String(contentsOf: configURL, encoding: .utf8),
              let rawURL = extractProxyURL(from: content),
              !rawURL.isEmpty else {
            return nil
        }

        let sanitized = ProxyURLValidator.sanitize(rawURL)
        guard ProxyURLValidator.validate(sanitized) == .valid else {
            return nil
        }

        return sanitized
    }

    nonisolated private static func extractProxyURL(from content: String) -> String? {
        let pattern = #"(?m)^proxy-url:\s*([^\n]*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..<content.endIndex, in: content)),
              match.numberOfRanges >= 2,
              let range = Range(match.range(at: 1), in: content) else {
            return nil
        }

        return unquoteYAMLScalar(String(content[range]))
    }

    nonisolated private static func unquoteYAMLScalar(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2,
              trimmed.first == "\"",
              trimmed.last == "\"" else {
            return trimmed
        }

        let inner = trimmed.dropFirst().dropLast()
        return inner
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }

    nonisolated static private func proxyDictionary(from url: URL) -> [AnyHashable: Any]? {
        guard let host = url.host else { return nil }
        let port = url.port ?? (url.scheme == "https" ? 443 : 8080)

        var dict: [AnyHashable: Any] = [:]

        switch url.scheme?.lowercased() {
        case "http":
            dict[kCFNetworkProxiesHTTPEnable] = true
            dict[kCFNetworkProxiesHTTPProxy] = host
            dict[kCFNetworkProxiesHTTPPort] = port

            // Also enable for HTTPS using the same proxy
            dict[kCFNetworkProxiesHTTPSEnable] = true
            dict[kCFNetworkProxiesHTTPSProxy] = host
            dict[kCFNetworkProxiesHTTPSPort] = port

        case "https":
            dict[kCFNetworkProxiesHTTPSEnable] = true
            dict[kCFNetworkProxiesHTTPSProxy] = host
            dict[kCFNetworkProxiesHTTPSPort] = port

        case "socks5":
            dict[kCFStreamPropertySOCKSProxyHost] = host
            dict[kCFStreamPropertySOCKSProxyPort] = port
            dict[kCFStreamPropertySOCKSVersion] = kCFStreamSocketSOCKSVersion5

            // Add authentication if present
            if let user = url.user {
                dict[kCFStreamPropertySOCKSUser] = user
            }
            if let password = url.password {
                dict[kCFStreamPropertySOCKSPassword] = password
            }

        default:
            return nil
        }

        return dict
    }
}
