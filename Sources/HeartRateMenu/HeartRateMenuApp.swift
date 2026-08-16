import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let central = HeartRateCentral()
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        central.start()

        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenuPopover(central: central))

        let statusItem = NSStatusBar.system.statusItem(withLength: 58)
        guard let button = statusItem.button else { return }
        button.title = ""
        button.image = nil
        button.target = self
        button.action = #selector(togglePopover(_:))

        let metricsView = PassthroughHostingView(rootView: MenuBarHeartRateView(central: central))
        metricsView.frame = button.bounds
        metricsView.autoresizingMask = [.width, .height]
        button.addSubview(metricsView)
        self.statusItem = statusItem
    }

    func applicationWillTerminate(_ notification: Notification) {
        central.stop()
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}

private final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

private struct MenuBarHeartRateView: View {
    @ObservedObject var central: HeartRateCentral

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.fill")
                .font(.system(size: 11, weight: .semibold))
            Text(central.displayHeartRate)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(central.isFresh ? .green : .secondary)
        .frame(width: 54, height: 22, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("实时心率 \(central.displayHeartRate) bpm")
    }
}

@main
struct HeartRateMenuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}
