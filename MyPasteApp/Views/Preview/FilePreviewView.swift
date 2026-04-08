//
//  FilePreviewView.swift
//  MyPasteApp
//

import AppKit
import SwiftUI

struct FilePreviewView: View {
    let path: String

    @State private var thumbnail: NSImage?

    var body: some View {
        ZStack {
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Fallback placeholder: ícone do Finder enquanto carrega.
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: path) {
            if let cached = FileThumbnailService.shared.cached(
                for: path,
                size: CGSize(width: 360, height: 360)
            ) {
                thumbnail = cached
                return
            }
            thumbnail = await FileThumbnailService.shared.thumbnail(
                for: path,
                size: CGSize(width: 360, height: 360)
            )
        }
    }
}
