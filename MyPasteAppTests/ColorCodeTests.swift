//
//  ColorCodeTests.swift
//  MyPasteAppTests
//

import AppKit
import Testing
@testable import MyPasteApp

@Suite("ColorCode")
struct ColorCodeTests {

    // MARK: - Parsing

    @Test("six-digit hex")
    func sixDigitHex() throws {
        let color = try #require(ColorCode.parse("#3A86FF"))
        #expect(color.byteComponents == (58, 134, 255))
        #expect(color.alpha == 1)
    }

    @Test("three-digit hex expands each digit")
    func threeDigitHex() throws {
        let color = try #require(ColorCode.parse("#abc"))
        #expect(color.byteComponents == (170, 187, 204))
    }

    @Test("eight-digit hex carries alpha")
    func eightDigitHex() throws {
        let color = try #require(ColorCode.parse("#3A86FF80"))
        #expect(color.byteComponents == (58, 134, 255))
        #expect(abs(color.alpha - 128.0 / 255.0) < 0.001)
    }

    @Test("rgb with and without spaces")
    func rgbFunction() throws {
        let spaced = try #require(ColorCode.parse("rgb(58, 134, 255)"))
        let tight = try #require(ColorCode.parse("RGB(58,134,255)"))
        #expect(spaced == tight)
        #expect(spaced.byteComponents == (58, 134, 255))
    }

    @Test("rgba carries alpha")
    func rgbaFunction() throws {
        let color = try #require(ColorCode.parse("rgba(58, 134, 255, 0.5)"))
        #expect(color.alpha == 0.5)
    }

    @Test("hsl round-trips close to the rgb it came from")
    func hslFunction() throws {
        // hsl→rgb is not the exact inverse of rgb→hsl at integer precision:
        // #3A86FF reports as hsl(217, 100%, 61%), and that hsl parses back to
        // (56, 132, 255). Both numbers are pinned here on purpose — a change
        // to the rounding shows up as a failure instead of drifting quietly.
        let color = try #require(ColorCode.parse("hsl(217, 100%, 61%)"))
        #expect(color.byteComponents == (56, 132, 255))
    }

    @Test("a negative hue wraps instead of clamping")
    func negativeHueWraps() throws {
        // Hue is an angle: -60° is 300°, which is magenta. Without the wrap
        // the arithmetic produced negative channels that clamped to something
        // else entirely, silently — including through "Copy Color as".
        let negative = try #require(ColorCode.parse("hsl(-60, 100%, 50%)"))
        let equivalent = try #require(ColorCode.parse("hsl(300, 100%, 50%)"))
        #expect(negative.byteComponents == equivalent.byteComponents)
        #expect(negative.byteComponents == (255, 0, 255))
    }

    @Test("a hue past 360 wraps too, in both directions")
    func hueWrapsBothWays() throws {
        let over = try #require(ColorCode.parse("hsl(420, 100%, 50%)"))
        let under = try #require(ColorCode.parse("hsl(-300, 100%, 50%)"))
        let plain = try #require(ColorCode.parse("hsl(60, 100%, 50%)"))
        #expect(over.byteComponents == plain.byteComponents)
        #expect(under.byteComponents == plain.byteComponents)
    }

    @Test("leading and trailing whitespace is ignored")
    func trimsWhitespace() {
        #expect(ColorCode.parse("  #3A86FF \n") != nil)
    }

    @Test("input longer than a colour could ever be is rejected without a copy")
    func rejectsLongInputEarly() {
        // The guard exists so a 1 MB text card doesn't copy a megabyte on
        // every re-render just to be told it isn't a colour. The behaviour it
        // buys — nothing that long is a colour — is what's pinned here.
        #expect(ColorCode.parse(String(repeating: "a", count: 1_000_000)) == nil)
        let padded = String(repeating: " ", count: ColorCode.maxParsableLength) + "#3A86FF"
        #expect(ColorCode.parse(padded) == nil)
        // And the cap is comfortably above any real colour, whitespace included.
        #expect(ColorCode.parse("   hsla(217.5, 100%, 61%, 0.5)   ") != nil)
    }

    @Test("text that merely contains a colour is not a colour")
    func rejectsEmbeddedColour() {
        // The whole point of the rule: a stylesheet in the history must not
        // turn into a colour item, or "Copy Color as" has no single answer.
        #expect(ColorCode.parse("body { color: #3A86FF; }") == nil)
        #expect(ColorCode.parse("#3A86FF is the accent") == nil)
    }

    @Test("malformed input is rejected")
    func rejectsGarbage() {
        #expect(ColorCode.parse("") == nil)
        #expect(ColorCode.parse("#12345") == nil)
        #expect(ColorCode.parse("#GGGGGG") == nil)
        #expect(ColorCode.parse("rgb(58, 134)") == nil)
        #expect(ColorCode.parse("rgb(300, 0, 0)") == nil)
        #expect(ColorCode.parse("hsl(217, 100, 61%)") == nil)
    }

    // MARK: - Formatting

    @Test("hex is upper case and drops alpha when opaque")
    func formatsHex() throws {
        let color = try #require(ColorCode.parse("rgb(58, 134, 255)"))
        #expect(color.formatted(as: .hex) == "#3A86FF")
    }

    @Test("hex keeps alpha when translucent")
    func formatsHexWithAlpha() throws {
        let color = try #require(ColorCode.parse("rgba(58, 134, 255, 0.5)"))
        #expect(color.formatted(as: .hex) == "#3A86FF80")
    }

    @Test("rgb and hsl formatting")
    func formatsFunctions() throws {
        let color = try #require(ColorCode.parse("#3A86FF"))
        #expect(color.formatted(as: .rgb) == "rgb(58, 134, 255)")
        #expect(color.formatted(as: .hsl) == "hsl(217, 100%, 61%)")
    }

    @Test("translucent colours use the a-suffixed functions")
    func formatsFunctionsWithAlpha() throws {
        let color = try #require(ColorCode.parse("#3A86FF80"))
        #expect(color.formatted(as: .rgb) == "rgba(58, 134, 255, 0.5)")
        #expect(color.formatted(as: .hsl) == "hsla(217, 100%, 61%, 0.5)")
    }

    @Test("grey has no meaningful hue and reports zero saturation")
    func formatsGrey() throws {
        let color = try #require(ColorCode.parse("#808080"))
        #expect(color.formatted(as: .hsl) == "hsl(0, 0%, 50%)")
    }

    @Test("a hue that rounds up to 360 wraps back to 0")
    func formatsHueWrapsAt360() throws {
        // #FF0001's raw hue is ~359.7647 — rounding lands it on 360, which is
        // the same angle as 0. Left unwrapped, formatting would print
        // "hsl(360, ...)" instead of the canonical "hsl(0, ...)".
        let color = try #require(ColorCode.parse("#FF0001"))
        #expect(color.formatted(as: .hsl) == "hsl(0, 100%, 50%)")
    }

    // MARK: - Legibility

    @Test("an opaque colour's composited luminance is its own, regardless of backdrop")
    func luminanceOpaqueIgnoresBackdrop() throws {
        let black = try #require(ColorCode.parse("#000000"))
        #expect(black.luminance(overBackdropLuminance: 0.85) == 0)
        let white = try #require(ColorCode.parse("#FFFFFF"))
        #expect(abs(white.luminance(overBackdropLuminance: 0.85) - 1) < 0.0001)
    }

    @Test("a fully transparent colour's composited luminance is just the backdrop's")
    func luminanceZeroAlphaEqualsBackdrop() throws {
        let color = try #require(ColorCode.parse("rgba(0, 0, 0, 0)"))
        #expect(abs(color.luminance(overBackdropLuminance: 0.85) - 0.85) < 0.0001)
    }

    @Test("a low-alpha dark colour reads near the backdrop, not near its own black")
    func luminanceLowAlphaDarkReadsNearBackdrop() throws {
        // The bug this guards: rgba(0, 0, 0, 0.05) is pure black by channel,
        // but composited over a near-white backdrop (0.85) the result is
        // near-white too — nowhere close to the raw channels' 0.
        let color = try #require(ColorCode.parse("rgba(0, 0, 0, 0.05)"))
        #expect(color.luminance(overBackdropLuminance: 0.85) > 0.55)
    }

    // MARK: - NSColor

    @Test("reads an NSColor through sRGB")
    func fromNSColor() throws {
        let color = try #require(ColorCode(NSColor(srgbRed: 58.0 / 255,
                                                  green: 134.0 / 255,
                                                  blue: 1,
                                                  alpha: 1)))
        #expect(color.formatted(as: .hex) == "#3A86FF")
    }
}

private extension ColorCode {
    /// The three channels as 0...255 integers, for readable expectations.
    var byteComponents: (Int, Int, Int) {
        (Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded()))
    }
}
