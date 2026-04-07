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
        MenuBarExtra("MyPasteApp", systemImage: "doc.on.clipboard") {
            MenuBarContent(appDelegate: appDelegate)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            if let container = appDelegate.modelContainer {
                PreferencesView()
                    .modelContainer(container)
            } else {
                Text("Carregando…").padding()
            }
        }
    }
}

struct MenuBarContent: View {
    let appDelegate: AppDelegate

    var body: some View {
        Button("Mostrar histórico  ⌘⇧V") {
            appDelegate.overlay?.toggle()
        }
        Divider()
        SettingsLink {
            Text("Preferências…")
        }
        Divider()
        Button("Sair") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
