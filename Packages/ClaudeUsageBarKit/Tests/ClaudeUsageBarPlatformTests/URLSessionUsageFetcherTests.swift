import ClaudeUsageBarCore
import ClaudeUsageBarPlatform
import ClaudeUsageBarTestSupport
import Foundation
import Testing

/// `URLSessionUsageFetcher` against the real endpoint, which a CI runner has no token for.
///
/// Needs network access; the signed-in test also needs Claude Code signed in on this Mac
/// with a current token (running Claude Code refreshes it).
@Suite("URLSessionUsageFetcher against the real endpoint", .requiresLocalMachine)
struct URLSessionUsageFetcherTests {
    static let fetcher = URLSessionUsageFetcher(timeout: Tuning.default.requestTimeout)

    @Test
    func `an invalid token gets an HTTP answer Core reads as expired`() async throws {
        let response = try await Self.fetcher.fetchUsage(with: OAuthAccessToken("invalid-token"))
        #expect(response.statusCode == 401)
        #expect(throws: UsageError.tokenExpired) {
            try response.snapshot()
        }
    }

    @Test
    func `the signed-in token gets a snapshot with a weekly window`() async throws {
        let token = try await SecurityCLITokenProvider().accessToken()
        let response = try await Self.fetcher.fetchUsage(with: token)
        let snapshot = try response.snapshot()
        let weekly = try #require(snapshot.sevenDay, "the response has no seven_day window")
        #expect((0 ... 100).contains(weekly.utilization))
        #expect(weekly.resetsAt != nil)
    }

    @Test
    func `keeps the UsageFetching contract the fake is held to`() async {
        await UsageFetchingContract.check(Self.fetcher, with: OAuthAccessToken("invalid-token"))
    }
}
