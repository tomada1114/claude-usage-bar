import ClaudeUsageBarCore
import Foundation
import Testing

/// What an HTTP answer from the usage endpoint means: a snapshot, or which failure.
@Suite("UsageResponse")
struct UsageResponseTests {
    /// A real response, trimmed; the keys the app ignores are kept to prove it does.
    static let sample = Data("""
    {"five_hour":{"utilization":19.0,"resets_at":"2026-09-29T22:00:00.633960+00:00",
    "limit_dollars":null},
    "seven_day":{"utilization":76.0,"resets_at":"2026-09-30T12:00:00.633985+00:00"},
    "seven_day_opus":null,
    "limits":[{"kind":"weekly_all","percent":76,"resets_at":"2026-09-30T12:00:00.633985+00:00"}],
    "member_dashboard_available":false}
    """.utf8)

    static let weeklyAll = #"{"kind":"weekly_all","percent":4,"scope":null}"#
    static let fableEntry = """
    {"kind":"weekly_scoped","group":"weekly","percent":6,"is_active":true,
    "resets_at":"2026-11-11T12:00:00.560298+00:00",
    "scope":{"model":{"id":null,"display_name":"Fable"},"surface":null}}
    """

    /// The shape of a real response: the model's limit is an entry of `limits`, not a key.
    static func limits(_ entries: String) -> UsageResponse {
        ok(#"{"seven_day":null,"limits":[\#(entries)]}"#)
    }

    static func ok(_ json: String) -> UsageResponse {
        UsageResponse(statusCode: 200, body: Data(json.utf8))
    }

    @Test
    func `decodes both windows from a real response`() throws {
        let snapshot = try UsageResponse(statusCode: 200, body: Self.sample).snapshot()
        #expect(snapshot.sevenDay?.utilization == 76)
        #expect(snapshot.fiveHour?.utilization == 19)
        // 2026-09-30T12:00Z and 2026-09-29T22:00Z, worked out by hand, plus the fraction.
        let weekly = try #require(snapshot.sevenDay?.resetsAt).timeIntervalSince1970
        let fiveHour = try #require(snapshot.fiveHour?.resetsAt).timeIntervalSince1970
        #expect(abs(weekly - 1_790_769_600.633985) < 1e-5)
        #expect(abs(fiveHour - 1_790_719_200.63396) < 1e-5)
    }

    @Test(arguments: [200, 204, 299])
    func `any 2xx status is a success`(status: Int) throws {
        let response = UsageResponse(statusCode: status, body: Data(#"{"seven_day":null}"#.utf8))
        #expect(try response.snapshot() == UsageSnapshot(fiveHour: nil, sevenDay: nil))
    }

    @Test
    func `a null or missing window decodes as absent`() throws {
        let snapshot = try Self.ok(#"{"five_hour":null}"#).snapshot()
        #expect(snapshot == UsageSnapshot(fiveHour: nil, sevenDay: nil))
    }

    @Test
    func `a window without a utilization is absent`() throws {
        let json = #"{"seven_day":{"utilization":null,"resets_at":"2026-09-30T12:00:00+00:00"}}"#
        #expect(try Self.ok(json).snapshot().sevenDay == nil)
    }

    @Test
    func `a missing, null, or unreadable reset time leaves only the time unknown`() throws {
        let json = """
        {"seven_day":{"utilization":76},"five_hour":{"utilization":19.5,"resets_at":"soon"}}
        """
        let snapshot = try Self.ok(json).snapshot()
        #expect(snapshot.sevenDay == UsageWindow(utilization: 76, resetsAt: nil))
        #expect(snapshot.fiveHour == UsageWindow(utilization: 19.5, resetsAt: nil))
    }

    @Test
    func `a field of the wrong type is ignored rather than failing the whole response`() throws {
        let json = #"{"seven_day":{"utilization":"76"},"five_hour":{"utilization":19}}"#
        let snapshot = try Self.ok(json).snapshot()
        #expect(snapshot.sevenDay == nil)
        #expect(snapshot.fiveHour?.utilization == 19)
    }

    @Test
    func `reads the Fable window from the scoped weekly limit`() throws {
        let snapshot = try Self.limits("\(Self.weeklyAll),\(Self.fableEntry)").snapshot()
        #expect(snapshot.fable?.utilization == 6)
        // 2026-11-11T12:00Z worked out by hand, plus the fraction.
        let reset = try #require(snapshot.fable?.resetsAt).timeIntervalSince1970
        #expect(abs(reset - 1_794_398_400.560298) < 1e-5)
    }

    @Test
    func `a response without a Fable limit has no Fable window`() throws {
        #expect(try Self.limits(Self.weeklyAll).snapshot().fable == nil)
        #expect(try Self.ok(#"{"seven_day":null}"#).snapshot().fable == nil)
        #expect(try Self.ok(#"{"limits":null}"#).snapshot().fable == nil)
    }

    @Test
    func `a scoped limit for another model or kind is not Fable`() throws {
        let sonnet = Self.fableEntry.replacingOccurrences(of: "Fable", with: "Sonnet")
        let notScoped = Self.fableEntry.replacingOccurrences(
            of: "weekly_scoped",
            with: "weekly_all",
        )
        #expect(try Self.limits(sonnet).snapshot().fable == nil)
        #expect(try Self.limits(notScoped).snapshot().fable == nil)
    }

    @Test
    func `a malformed limits entry spoils only itself`() throws {
        let entries = #"3,"x",{"kind":"weekly_scoped","percent":"6","scope":null},"# + Self
            .fableEntry
        #expect(try Self.limits(entries).snapshot().fable?.utilization == 6)
        #expect(try Self.ok(#"{"limits":"none"}"#).snapshot().fable == nil)
    }

    @Test
    func `a Fable limit without a percent is absent`() throws {
        let noPercent = Self.fableEntry.replacingOccurrences(of: #""percent":6,"#, with: "")
        #expect(try Self.limits(noPercent).snapshot().fable == nil)
    }

    @Test(arguments: [401, 403])
    func `an authentication status means the token expired`(status: Int) {
        #expect(throws: UsageError.tokenExpired) {
            try UsageResponse(statusCode: status, body: Data()).snapshot()
        }
    }

    @Test(arguments: [199, 300, 400, 404, 429, 500, 503])
    func `any other status is an unexpected response carrying the status`(status: Int) {
        #expect(throws: UsageError.unexpectedResponse(statusCode: status)) {
            try UsageResponse(statusCode: status, body: Self.sample).snapshot()
        }
    }

    @Test(arguments: ["", "[]", "null", "76", "{", "<html></html>"])
    func `a 2xx body that is not a JSON object is an unexpected response`(body: String) {
        #expect(throws: UsageError.unexpectedResponse(statusCode: 200)) {
            try Self.ok(body).snapshot()
        }
    }
}
