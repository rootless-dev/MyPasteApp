//
//  MyPasteAppApp.swift
//  MyPasteApp
//
//  Created by Carlos Eduardo on 07/04/26.
//

import SwiftData
import SwiftUI

@main
struct MyPasteAppApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            if let container = appDelegate.modelContainer {
                PreferencesView()
                    .modelContainer(container)
            } else {
                Text("Loading…").padding()
            }
        }
    }
}
