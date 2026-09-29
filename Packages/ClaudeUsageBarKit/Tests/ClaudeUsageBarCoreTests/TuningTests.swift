import ClaudeUsageBarCore
import Testing

@Suite("Tuning")
struct TuningTests {
    @Test
    func `the default polls every two minutes and gives a request thirty seconds`() {
        #expect(Tuning.default.refreshInterval == .seconds(120))
        #expect(Tuning.default.requestTimeout == .seconds(30))
    }
}
