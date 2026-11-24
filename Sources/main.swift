// NightShift — evita el reposo por inactividad durante 1–4 horas.
// Autor: Diego Bogotá Linares — https://diegobogota.com
//
// Mecanismo: IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleSystemSleep)
// (la misma API que usa `caffeinate`). La pantalla se apaga y se bloquea
// normalmente; solo se evita el reposo del sistema que apaga el Wi-Fi.

import AppKit
import IOKit.pwr_mgt

// MARK: - Estado de energía

final class PowerState {
    static let shared = PowerState()

    private var assertionID: IOPMAssertionID = 0
    private(set) var isActive = false
    private(set) var activeHours: Int = 0
    private(set) var deadline: Date?
    private var timer: Timer?

    private init() {}

    func activate(hours: Int) {
        deactivate()

        var assertionID = IOPMAssertionID()
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "NightShift" as CFString,
            &assertionID
        )
        guard result == kIOReturnSuccess else {
            NSLog("NightShift: no se pudo crear la aserción: \(result)")
            return
        }
        assertion = assertionID

        deadline = Date().addingTimeInterval(TimeInterval(hours) * 3600)
        activeHours = hours
        isActive = true

        // Temporizador de 1 s: refresca el menú y desactiva al vencer.
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if let deadline = self.deadline, Date() >= deadline {
                self.deactivate()
            } else {
                AppDelegate.shared.refreshMenu()
            }
        }
        AppDelegate.shared.refreshMenu()
    }

    func deactivate() {
        if isActive {
            IOPMAssertionRelease(assertion)
        }
        timer?.invalidate()
        timer = nil
        deadline = nil
        activeHours = 0
        isActive = false
        AppDelegate.shared.refreshMenu()
    }

    private var assertion = IOPMAssertionID(0)
}

// MARK: - Delegate de la app

final class AppDelegate: NSObject, NSApplicationDelegate {
    static let shared = AppDelegate()

    private var statusItem: NSStatusItem?
    private var menu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "🌙"
        item.menu = buildMenu()
        statusItem = item
        menu = item.menu
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let title = NSMenuItem(title: "NightShift", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())

        for hours in [1, 2, 3, 4] {
            let item = NSMenuItem(
                title: "\(hours) hora\(hours > 1 ? "s" : "")",
                action: #selector(activateHours(_:)),
                keyEquivalent: ""
            )
            item.tag = hours
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let disable = NSMenuItem(
            title: "Desactivar",
            action: #selector(deactivateClicked),
            keyEquivalent: "d"
        )
        disable.tag = 100
        menu.addItem(disable)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Salir",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quit)

        return menu
    }

    // MARK: Acciones

    @objc private func activateHours(_ sender: NSMenuItem) {
        PowerState.shared.activate(hours: sender.tag)
    }

    @objc private func deactivateClicked() {
        PowerState.shared.deactivate()
    }

    // MARK: Refresco del menú

    func refreshMenu() {
        guard let button = statusItem?.button, let menu = menu else { return }

        if PowerState.shared.isActive, let deadline = PowerState.shared.deadline {
            let remaining = max(0, Int(deadline.timeIntervalSinceNow.rounded()))
            let h = remaining / 3600
            let m = (remaining % 3600) / 60
            let s = remaining % 60
            button.title = String(format: "🌙 %d:%02d:%02d", h, m, s)
        } else {
            button.title = "🌙"
        }

        for item in menu.items {
            switch item.tag {
            case 1, 2, 3, 4:
                item.state = (PowerState.shared.isActive && item.tag == PowerState.shared.activeHours) ? .on : .off
            case 100:
                item.isEnabled = PowerState.shared.isActive
            default:
                break
            }
        }
    }
}

// MARK: - Arranque

let app = NSApplication.shared
let appDelegate = AppDelegate.shared
app.delegate = appDelegate
app.setActivationPolicy(.accessory)
app.run()
