//
//  CustomServiceUpdateService.swift
//  Edx
//
//  Checks GitHub releases for user-defined custom services.
//

import Foundation

actor CustomServiceUpdateService {
    static let shared = CustomServiceUpdateService()

    private let session: URLSession

    init(session: URLSession = URLSession.shared) {
        self.session = session
    }

    func checkLatestRelease(for repository: GitHubRepository) async throws -> CustomServiceUpdateStatus {
        let url = repository.latestReleaseAPIURL
        var request = URLRequest(url: url)
        request.addValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.addValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.addValue("Edx/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CustomServiceUpdateError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let release = try JSONDecoder.githubReleaseDecoder.decode(GitHubLatestReleaseResponse.self, from: data)
            return CustomServiceUpdateStatus(
                repository: repository.slug,
                latestVersion: release.normalizedVersion,
                latestReleaseTitle: release.displayTitle,
                latestReleaseURL: release.htmlURL,
                latestPublishedAt: release.publishedAt,
                lastCheckedAt: Date(),
                errorMessage: nil
            )
        case 404:
            throw CustomServiceUpdateError.releaseNotFound
        case 403:
            throw CustomServiceUpdateError.rateLimited
        default:
            throw CustomServiceUpdateError.httpStatus(httpResponse.statusCode)
        }
    }
}

nonisolated struct GitHubRepository: Sendable, Hashable {
    let owner: String
    let name: String

    var slug: String { "\(owner)/\(name)" }
    var latestReleaseAPIURL: URL {
        URL(string: "https://api.github.com/repos/\(owner)/\(name)/releases/latest")!
    }

    static func normalize(_ input: String) -> GitHubRepository? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let withoutGitSuffix = trimmed.hasSuffix(".git") ? String(trimmed.dropLast(4)) : trimmed
        if let url = URL(string: withoutGitSuffix), let host = url.host?.lowercased(), host == "github.com" {
            return normalizePath(url.path)
        }

        return normalizePath(withoutGitSuffix)
    }

    private static func normalizePath(_ rawPath: String) -> GitHubRepository? {
        let cleaned = rawPath
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let parts = cleaned
            .split(separator: "/")
            .map(String.init)

        guard parts.count >= 2 else { return nil }
        let owner = parts[0]
        let repo = parts[1]
        guard isValidSegment(owner), isValidSegment(repo) else { return nil }
        return GitHubRepository(owner: owner, name: repo)
    }

    private static func isValidSegment(_ segment: String) -> Bool {
        !segment.isEmpty && segment.range(of: #"^[A-Za-z0-9_.-]+$"#, options: .regularExpression) != nil
    }
}

nonisolated enum CustomServiceUpdateError: Error, Sendable {
    case invalidRepository
    case invalidResponse
    case releaseNotFound
    case rateLimited
    case httpStatus(Int)

    var messageKey: String {
        switch self {
        case .invalidRepository:
            return "custom.service.update.error.invalidRepository"
        case .invalidResponse:
            return "custom.service.update.error.invalidResponse"
        case .releaseNotFound:
            return "custom.service.update.error.releaseNotFound"
        case .rateLimited:
            return "custom.service.update.error.rateLimited"
        case .httpStatus:
            return "custom.service.update.error.httpStatus"
        }
    }

    var statusCode: Int? {
        if case .httpStatus(let statusCode) = self {
            return statusCode
        }
        return nil
    }
}

nonisolated private struct GitHubLatestReleaseResponse: Decodable {
    let tagName: String
    let name: String?
    let htmlURL: String
    let publishedAt: Date?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlURL = "html_url"
        case publishedAt = "published_at"
    }

    var normalizedVersion: String {
        tagName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var displayTitle: String {
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedName.isEmpty ? tagName : trimmedName
    }
}

nonisolated private extension JSONDecoder {
    static var githubReleaseDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
