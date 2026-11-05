import BuehneCore
import Testing

@Test func barScaleIsBaselineAt520AndClampsTheEnds() {
    #expect(BarScale.factor(windowWidth: 520) == 1)
    #expect(BarScale.factor(windowWidth: 100) == 0.6)
    #expect(BarScale.factor(windowWidth: 360) == 360.0 / 520.0)
    #expect(BarScale.factor(windowWidth: 1200) == 1.0)
    #expect(BarScale.factor(windowWidth: 2000) == 1.0)
    #expect(BarScale.factor(windowWidth: 0) == 0.6)
}

@Test func barScaleIsMonotonicAndSmooth() {
    var previous = BarScale.factor(windowWidth: 200)
    var width = 210.0
    while width <= 1400 {
        let next = BarScale.factor(windowWidth: width)
        #expect(next >= previous)
        #expect(next - previous <= 10 / BarScale.baselineWidth + 0.000_001)
        previous = next
        width += 10
    }
}

@Test func barScaleKeepsIconsAndHitsAboveTheFloor() {
    let small = BarScale.factor(windowWidth: 200)
    #expect(BarScale.icon(12, scale: small) >= 16)
    #expect(BarScale.hitSide(32, scale: small) >= 24)
    #expect(BarScale.hitSide(32, scale: 1) == 32)
    #expect(BarScale.hoverMagnification(scale: 1) == 1.2)
    #expect(BarScale.hoverMagnification(scale: 1.0) > BarScale.hoverMagnification(scale: 0.6))
    #expect(BarScale.icon(30, scale: 1) > BarScale.icon(30, scale: 0.6))
}
