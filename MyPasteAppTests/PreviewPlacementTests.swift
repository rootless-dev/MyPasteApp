//
//  PreviewPlacementTests.swift
//  MyPasteAppTests
//

import CoreGraphics
import Testing

@testable import MyPasteApp

@Suite("Preview placement")
struct PreviewPlacementTests {
    // A 1440x900 screen with the menu bar taken off the top, and the panel
    // as ItemPreviewPanel.windowSize measures it.
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 875)
    private let panel = CGSize(width: 520, height: 392)
    private let corner: CGFloat = 12
    private let beak: CGFloat = 22

    private func solve(anchor: CGRect) -> PreviewPlacement.Result {
        PreviewPlacement.solve(anchor: anchor,
                               panelSize: panel,
                               visibleFrame: screen,
                               cornerRadius: corner,
                               beakWidth: beak)
    }

    @Test("A card in the middle centres the panel and puts the beak dead centre")
    func centredCard() {
        let card = CGRect(x: 700, y: 100, width: 200, height: 220)
        let result = solve(anchor: card)
        #expect(result.frame.minX == 540)
        #expect(result.frame.minY == card.maxY + PreviewPlacement.margin)
        #expect(result.beakOffset == 260)
    }

    @Test("A card at the left edge clamps the panel and slides the beak left")
    func leftEdgeCard() {
        // The panel would start at -150, which is off-screen; it stops at the
        // inset instead, and the beak has to travel to stay over the card.
        let card = CGRect(x: 10, y: 100, width: 200, height: 220)
        let result = solve(anchor: card)
        #expect(result.frame.minX == PreviewPlacement.edgeInset)
        #expect(result.beakOffset == card.midX - PreviewPlacement.edgeInset)
    }

    @Test("A card at the right edge clamps the panel and slides the beak right")
    func rightEdgeCard() {
        let card = CGRect(x: 1230, y: 100, width: 200, height: 220)
        let result = solve(anchor: card)
        let expectedX = screen.maxX - panel.width - PreviewPlacement.edgeInset
        #expect(result.frame.minX == expectedX)
        #expect(result.beakOffset == card.midX - expectedX)
    }

    @Test("A card too far into the corner for the beak to reach loses the beak")
    func cardOutOfBeakReach() {
        // The beak's tip can't sit inside the rounded corner: with the panel
        // clamped at x=8, this card's centre lands at 12, and the nearest
        // legal tip is cornerRadius + beakWidth/2 = 23.
        let card = CGRect(x: 0, y: 100, width: 40, height: 220)
        let result = solve(anchor: card)
        #expect(result.frame.minX == PreviewPlacement.edgeInset)
        #expect(result.beakOffset == nil)
    }

    @Test("A panel that can't fit above the card is pushed down and loses the beak")
    func noRoomAbove() {
        // Phase 2's behaviour, preserved: the panel is clamped to the top of
        // the screen. The beak goes because the panel now overlaps the card —
        // a beak here would point into the panel's own body.
        let card = CGRect(x: 700, y: 600, width: 200, height: 220)
        let result = solve(anchor: card)
        #expect(result.frame.maxY <= screen.maxY - PreviewPlacement.edgeInset)
        #expect(result.frame.minY < card.maxY)
        #expect(result.beakOffset == nil)
    }

    @Test("A screen smaller than the panel still produces a frame inside it")
    func screenSmallerThanPanel() {
        let tiny = CGRect(x: 0, y: 0, width: 400, height: 300)
        let card = CGRect(x: 100, y: 40, width: 200, height: 100)
        let result = PreviewPlacement.solve(anchor: card,
                                            panelSize: panel,
                                            visibleFrame: tiny,
                                            cornerRadius: corner,
                                            beakWidth: beak)
        #expect(result.frame.minX >= tiny.minX)
        #expect(result.frame.minY >= tiny.minY)
    }

    @Test("A beak that exists is always far enough from both rounded corners")
    func beakStaysOffTheCorners() {
        // Swept across the whole strip of card positions the drawer can
        // produce, because the beak's legal range is the invariant that keeps
        // the tip from being drawn inside a corner's curve.
        for midX in stride(from: CGFloat(0), through: 1440, by: 20) {
            let card = CGRect(x: midX - 100, y: 100, width: 200, height: 220)
            let result = solve(anchor: card)
            guard let offset = result.beakOffset else { continue }
            #expect(offset >= corner + beak / 2)
            #expect(offset <= panel.width - corner - beak / 2)
        }
    }

    @Test("The beak, when it exists, sits over the card it points at")
    func beakPointsAtTheCard() {
        for midX in stride(from: CGFloat(0), through: 1440, by: 20) {
            let card = CGRect(x: midX - 100, y: 100, width: 200, height: 220)
            let result = solve(anchor: card)
            guard let offset = result.beakOffset else { continue }
            let tipOnScreen = result.frame.minX + offset
            #expect(tipOnScreen >= card.minX)
            #expect(tipOnScreen <= card.maxX)
        }
    }

    // MARK: - Detaching

    @Test("Detaching keeps the top edge exactly where it was")
    func detachedFrameKeepsTheTopEdge() {
        let anchored = CGRect(x: 300, y: 420, width: 520, height: 392)
        let detached = PreviewPlacement.detachedFrame(from: anchored, losing: 12)
        #expect(detached.maxY == anchored.maxY)
        #expect(detached.height == anchored.height - 12)
        #expect(detached.minY == anchored.minY + 12)
    }

    @Test("Detaching changes neither width nor left edge")
    func detachedFrameKeepsTheHorizontalAxis() {
        let anchored = CGRect(x: -137.5, y: 0, width: 520, height: 392)
        let detached = PreviewPlacement.detachedFrame(from: anchored, losing: 12)
        #expect(detached.minX == anchored.minX)
        #expect(detached.width == anchored.width)
    }

    @Test("Detaching a panel placed by solve() leaves the body where it was drawn")
    func detachedFrameMatchesTheSolvedPlacement() {
        // The beak strip sits below the body, so shedding it must not move
        // a single point of what the user is looking at.
        let card = CGRect(x: 600, y: 100, width: 200, height: 220)
        let solved = solve(anchor: card).frame
        let detached = PreviewPlacement.detachedFrame(from: solved, losing: 12)
        #expect(detached.maxY == solved.maxY)
        #expect(detached.minX == solved.minX)
        #expect(detached.height == 380)
    }
}
