//
//  PastePlainTextResolverTests.swift
//  MyPasteAppTests
//

import Testing

@testable import MyPasteApp

/// Locks the rule shared by every ⇧-aware paste path — `OverlayView`'s
/// click/`↵` handling and `ItemContextMenu`'s "Paste" entry — after it was
/// collapsed into `ItemActions.resolvePastePlainText` to fix the context
/// menu ignoring "Always paste as plain text" (it used to hardcode `false`).
@Suite("Paste plain text resolution")
struct PastePlainTextResolverTests {
    @Test("Neither the preference nor ⇧ pastes formatting")
    func defaultsToRich() {
        #expect(!ItemActions.resolvePastePlainText(alwaysPlainText: false, shiftHeld: false))
    }

    @Test("⇧ alone forces plain text")
    func shiftForcesPlain() {
        #expect(ItemActions.resolvePastePlainText(alwaysPlainText: false, shiftHeld: true))
    }

    @Test("The preference alone forces plain text")
    func preferenceForcesPlain() {
        #expect(ItemActions.resolvePastePlainText(alwaysPlainText: true, shiftHeld: false))
    }

    @Test("With the preference on, ⇧ changes nothing — it never inverts")
    func preferenceNeverInverts() {
        #expect(ItemActions.resolvePastePlainText(alwaysPlainText: true, shiftHeld: true))
    }
}
