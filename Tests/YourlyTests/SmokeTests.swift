import Testing

struct SmokeTests {
    @Test func smoke() {
        #expect(1 + 1 == 2)
    }
}
