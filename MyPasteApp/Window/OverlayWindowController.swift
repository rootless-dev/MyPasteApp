//
//  OverlayWindowController.swift
//  MyPasteApp
//

import AppKit
import SwiftData
import SwiftUI

@MainActor
final class OverlayWindowController: NSObject, NSWindowDelegate {
    private var window: NSPanel?
    private let modelContainer: ModelContainer
    private let onPick: (ClipboardItem) -> Void
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var previousApp: NSRunningApplication?

    init(modelContainer: ModelContainer, onPick: @escaping (ClipboardItem) -> Void) {
        self.modelContainer = modelContainer
        self.onPick = onPick
        super.init()
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    func toggle() {
        if window?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    private static let overlayHeight: CGFloat = 320

    /// Cria o `NSPanel` e faz layout inicial do SwiftUI antecipadamente, para
    /// que a primeira invocação da hotkey não pague o custo de layout durante
    /// a animação de abertura. Idempotente.
    func prepare() {
        guard window == nil else { return }
        let height = Self.overlayHeight
        let initial = NSRect(x: 0, y: 0, width: 800, height: height)

        let panel = NSPanel(
            contentRect: initial,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.delegate = self
        panel.alphaValue = 0

        let root = OverlayView(
            onPick: { [weak self] item in
                self?.onPick(item)
            },
            onDismiss: { [weak self] in self?.hide() }
        )
        .modelContainer(modelContainer)

        let host = NSHostingView(rootView: root)
        host.frame = panel.contentView?.bounds ?? initial
        host.autoresizingMask = [NSView.AutoresizingMask.width, NSView.AutoresizingMask.height]
        host.wantsLayer = true
        panel.contentView = host
        // Força o layout inicial agora, fora do hot path da hotkey.
        host.layoutSubtreeIfNeeded()
        window = panel

        // Pré-aquecimento "de verdade": exibe o painel brevemente fora da
        // tela visível e ordena saída no próximo runloop. Isso obriga o
        // SwiftUI a rodar onAppear e os loaders das previews uma vez no
        // startup, para que a primeira animação real não compita com esses
        // trabalhos assíncronos.
        let warmupFrame = NSRect(x: -10_000, y: -10_000, width: 800, height: height)
        panel.setFrame(warmupFrame, display: false)
        panel.orderFrontRegardless()
        host.layoutSubtreeIfNeeded()
        host.displayIfNeeded()
        DispatchQueue.main.async {
            panel.orderOut(nil)
        }
    }

    func show() {
        let frontmost = NSWorkspace.shared.frontmostApplication
        if frontmost?.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = frontmost
        }
        guard let screen = targetScreen(for: frontmost) else { return }
        prepare()
        guard let panel = window else { return }

        let height = Self.overlayHeight
        let frame = NSRect(
            x: screen.frame.minX,
            y: screen.visibleFrame.minY,
            width: screen.frame.width,
            height: height
        )

        // A janela é colocada DIRETAMENTE no frame final (sem slide pela
        // janela). O slide-up é feito internamente, transladando a layer da
        // contentView. Isso evita que a animação cruze a fronteira entre
        // monitores em setups multi-display, o que antes causava o "teleporte".
        panel.alphaValue = 0
        panel.setFrame(frame, display: false)
        panel.orderFrontRegardless()
        panel.makeKey()

        guard let hostLayer = panel.contentView?.layer else {
            panel.alphaValue = 1
            installClickOutsideMonitors()
            return
        }

        // Estado inicial: transladado pra baixo da própria janela.
        hostLayer.removeAnimation(forKey: "slideUp")
        hostLayer.removeAnimation(forKey: "fadeIn")
        hostLayer.setAffineTransform(CGAffineTransform(translationX: 0, y: -height))
        panel.alphaValue = 1

        // Rasterização durante a animação: o Core Animation tira um snapshot
        // bitmap da hierarquia uma vez e só translada o snapshot a cada frame,
        // em vez de recompor a árvore SwiftUI. Desligamos no completion para
        // não degradar a nitidez quando a janela está parada.
        hostLayer.shouldRasterize = true
        hostLayer.rasterizationScale = panel.backingScaleFactor
        // Garante que o conteúdo já está renderizado ANTES de a animação
        // começar, para que o primeiro frame do slide-up não pague o custo
        // de layout/draw da árvore SwiftUI.
        panel.contentView?.layoutSubtreeIfNeeded()
        panel.contentView?.displayIfNeeded()
        hostLayer.displayIfNeeded()

        let slide = CASpringAnimation(keyPath: "transform")
        slide.fromValue = CATransform3DMakeTranslation(0, -height, 0)
        slide.toValue = CATransform3DIdentity
        slide.damping = 18
        slide.stiffness = 220
        slide.mass = 1
        slide.initialVelocity = 0
        slide.duration = slide.settlingDuration
        slide.fillMode = .forwards
        slide.isRemovedOnCompletion = false

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        fade.duration = 0.18
        fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            hostLayer.setAffineTransform(.identity)
            hostLayer.opacity = 1
            hostLayer.shouldRasterize = false
            hostLayer.removeAnimation(forKey: "slideUp")
            hostLayer.removeAnimation(forKey: "fadeIn")
        }
        hostLayer.add(slide, forKey: "slideUp")
        hostLayer.add(fade, forKey: "fadeIn")
        CATransaction.commit()

        installClickOutsideMonitors()
    }

    func hide() {
        removeClickOutsideMonitors()
        guard let panel = window, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.18
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }

    private func installClickOutsideMonitors() {
        removeClickOutsideMonitors()
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            Task { @MainActor in self?.hide() }
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            guard let self else { return event }
            if event.window !== self.window {
                self.hide()
            }
            return event
        }
    }

    /// Resolve em qual `NSScreen` o overlay deve aparecer.
    ///
    /// Estratégia (em ordem):
    /// 1. Tela que contém a janela frontmost do app que estava em foco
    ///    (descoberta via `CGWindowListCopyWindowInfo`, sem precisar de
    ///    permissão de Accessibility).
    /// 2. Tela que contém o cursor do mouse — usada quando o app frontmost
    ///    não tem janelas visíveis (ex.: Finder mostrando só a área de
    ///    trabalho).
    /// 3. `NSScreen.main` como último recurso.
    private func targetScreen(for frontmost: NSRunningApplication?) -> NSScreen? {
        if let app = frontmost,
           app.bundleIdentifier != Bundle.main.bundleIdentifier,
           let screen = screenForFrontmostWindow(pid: app.processIdentifier) {
            return screen
        }
        if let screen = screenContainingMouse() {
            return screen
        }
        return NSScreen.main
    }

    private func screenForFrontmostWindow(pid: pid_t) -> NSScreen? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        // A lista vem do mais frontmost para o mais ao fundo. Pegamos a
        // primeira janela "normal" (layer 0) que pertença ao processo.
        for info in infoList {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t, ownerPID == pid else { continue }
            guard let layer = info[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            guard let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let cgBounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else { continue }
            // CGWindow usa origem no topo-esquerda do display primário; AppKit
            // usa rodapé-esquerda. Convertemos pegando o centro em coordenadas
            // do AppKit.
            guard let primary = NSScreen.screens.first else { continue }
            let primaryHeight = primary.frame.height
            let centerCG = CGPoint(x: cgBounds.midX, y: cgBounds.midY)
            let centerAppKit = CGPoint(x: centerCG.x, y: primaryHeight - centerCG.y)
            if let screen = NSScreen.screens.first(where: { $0.frame.contains(centerAppKit) }) {
                return screen
            }
        }
        return nil
    }

    private func screenContainingMouse() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) }
    }

    private func removeClickOutsideMonitors() {
        if let m = globalMouseMonitor {
            NSEvent.removeMonitor(m)
            globalMouseMonitor = nil
        }
        if let m = localMouseMonitor {
            NSEvent.removeMonitor(m)
            localMouseMonitor = nil
        }
    }
}
