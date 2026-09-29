import Foundation
import MyAppCore
import Testing

/// A fake, not a mock (`.claude/rules/testing.md` › Fakes, not mocks): it is a real
/// conforming implementation whose answers are data, and whose calls are recorded in a
/// value the test reads afterwards. No expectations are declared up front. Internal
/// rather than private so `LocalizationTests` drives the view model with this same fake.
final class FakeFrontmostAppProvider: FrontmostAppProviding, @unchecked Sendable {
    /// Safe without a lock: every test that uses it — this file's and
    /// `LocalizationTests`' — runs in a `@MainActor` suite, so the mutations and the
    /// reads happen on one actor. `@unchecked` is what lets a
    /// recording fake satisfy a `Sendable` port without a lock it does not need.
    private(set) var callCount = 0
    private let answers: [FrontmostApp?]

    /// Answers each call in order, repeating the last one once they run out.
    init(answering answers: [FrontmostApp?]) {
        self.answers = answers.isEmpty ? [nil] : answers
    }

    func currentFrontmostApp() -> FrontmostApp? {
        defer { callCount += 1 }
        return answers[min(callCount, answers.count - 1)]
    }
}

@MainActor
@Suite("FrontmostAppViewModel")
struct FrontmostAppViewModelTests {
    @Test
    func `starts unavailable, before anything asks the port`() {
        let provider = FakeFrontmostAppProvider(answering: [FrontmostApp(name: "Finder")])
        let model = FrontmostAppViewModel(provider: provider)
        #expect(model.frontmostApp == nil)
        #expect(model.label.resolved(in: .english) == "Frontmost: —")
        #expect(provider.callCount == 0)
    }

    @Test
    func `refresh publishes what the port answered`() {
        let app = FrontmostApp(name: "Finder", bundleIdentifier: "com.apple.finder")
        let model = FrontmostAppViewModel(provider: FakeFrontmostAppProvider(answering: [app]))
        model.refresh()
        #expect(model.frontmostApp == app)
        #expect(model.label.resolved(in: .english) == "Frontmost: Finder")
    }

    @Test
    func `refresh reports unavailable when the port answers nil`() {
        let model = FrontmostAppViewModel(provider: FakeFrontmostAppProvider(answering: [nil]))
        model.refresh()
        #expect(model.frontmostApp == nil)
        #expect(model.label.resolved(in: .english) == "Frontmost: —")
    }

    @Test
    func `each refresh asks the port again and takes the newer answer`() {
        let provider = FakeFrontmostAppProvider(answering: [
            FrontmostApp(name: "Finder"),
            nil,
            FrontmostApp(name: "Terminal"),
        ])
        let model = FrontmostAppViewModel(provider: provider)
        model.refresh()
        #expect(model.label.resolved(in: .english) == "Frontmost: Finder")
        model.refresh()
        #expect(model.label.resolved(in: .english) == "Frontmost: —")
        model.refresh()
        #expect(model.label.resolved(in: .english) == "Frontmost: Terminal")
        #expect(provider.callCount == 3)
    }

    @Test
    func `a bundle identifier is carried through as a value`() {
        let app = FrontmostApp(name: "Terminal", bundleIdentifier: "com.apple.Terminal")
        let model = FrontmostAppViewModel(provider: FakeFrontmostAppProvider(answering: [app]))
        model.refresh()
        #expect(model.frontmostApp?.bundleIdentifier == "com.apple.Terminal")
    }

    @Test
    func `a frontmost app without a bundle identifier is still a valid value`() {
        let app = FrontmostApp(name: "Some Helper")
        #expect(app.bundleIdentifier == nil)
        #expect(app == FrontmostApp(name: "Some Helper", bundleIdentifier: nil))
        #expect(app != FrontmostApp(name: "Some Helper", bundleIdentifier: "x"))
    }
}
