//
//  ItemRetentionTests.swift
//  MyPasteAppTests
//

import Foundation
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
