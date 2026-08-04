//
//  ItemRetentionTests.swift
//  MyPasteAppTests
//

import Foundation
import SwiftData
import Testing

@testable import MyPasteApp

@Suite("Item retention")
struct ItemRetentionTests {
    private let date = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("Nothing set means follow the global policy")
    func neutralIsGlobal() {
        #expect(ItemRetention.of(keepForever: false, expiresAt: nil) == .global)
    }

    @Test("Keep forever reads back as forever")
    func foreverRoundTrips() {
        #expect(ItemRetention.of(keepForever: true, expiresAt: nil) == .forever)
    }

    @Test("A date reads back as until")
    func untilRoundTrips() {
        #expect(ItemRetention.of(keepForever: false, expiresAt: date) == .until(date))
    }

    @Test("A date wins over keep forever")
    func dateWinsOverForever() {
        // The inconsistent state shouldn't be reachable — `fields` always
        // writes both — but if it ever is, the dated choice is the more
        // specific one, and honouring it is the safer failure: an item the
        // user asked to expire does expire.
        #expect(ItemRetention.of(keepForever: true, expiresAt: date) == .until(date))
    }

    @Test("Global clears both fields")
    func globalClearsBoth() {
        let fields = ItemRetention.global.fields
        #expect(fields.keepForever == false)
        #expect(fields.expiresAt == nil)
    }

    @Test("Forever sets the flag and clears the date")
    func foreverClearsTheDate() {
        let fields = ItemRetention.forever.fields
        #expect(fields.keepForever)
        #expect(fields.expiresAt == nil)
    }

    @Test("Until sets the date and clears the flag")
    func untilClearsTheFlag() {
        let fields = ItemRetention.until(date).fields
        #expect(fields.keepForever == false)
        #expect(fields.expiresAt == date)
    }

    @Test("Each offer lands the expected distance in the future")
    func offersResolveToDates() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(RetentionOffer.hour.date(from: now) == now.addingTimeInterval(3600))
        #expect(RetentionOffer.day.date(from: now) == now.addingTimeInterval(86_400))
        #expect(RetentionOffer.week.date(from: now) == now.addingTimeInterval(7 * 86_400))
        #expect(RetentionOffer.month.date(from: now) == now.addingTimeInterval(30 * 86_400))
    }

    @Test("Every offer has a title")
    func offersHaveTitles() {
        for offer in RetentionOffer.allCases {
            #expect(!offer.title.isEmpty)
        }
    }
}

@MainActor
@Suite("Item retention actions")
final class ItemRetentionActionTests {
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: ClipboardItem.self, Pinboard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private var context: ModelContext { container.mainContext }

    private func makeItem() -> ClipboardItem {
        let item = ClipboardItem(type: .text, preview: "a", contentHash: "a", textContent: "a")
        context.insert(item)
        return item
    }

    @Test("Setting forever clears any expiry date")
    func foreverClearsTheDate() {
        let item = makeItem()
        item.expiresAt = .now.addingTimeInterval(3600)

        ItemActions.setRetention(.forever, on: item)

        #expect(item.keepForever)
        #expect(item.expiresAt == nil)
    }

    @Test("Setting a date clears keep forever")
    func dateClearsForever() {
        let item = makeItem()
        item.keepForever = true
        let when = Date.now.addingTimeInterval(3600)

        ItemActions.setRetention(.until(when), on: item)

        #expect(item.keepForever == false)
        #expect(item.expiresAt == when)
    }

    @Test("Going back to global clears both")
    func globalClearsBoth() {
        let item = makeItem()
        item.keepForever = true
        item.expiresAt = .now

        ItemActions.setRetention(.global, on: item)

        #expect(item.keepForever == false)
        #expect(item.expiresAt == nil)
    }

    @Test("Assigning to a board fills the relationship, and nil clears it")
    func assignAndClear() {
        let item = makeItem()
        let board = Pinboard(name: "Work", colorHex: PinboardPalette.colors[0])
        context.insert(board)

        ItemActions.assign(item, to: board)
        #expect(item.pinboard?.id == board.id)

        ItemActions.assign(item, to: nil)
        #expect(item.pinboard == nil)
    }
}
