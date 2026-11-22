import AppKit
import SwiftUI
import CoreAudio
import CoreGraphics
import ServiceManagement

// MARK: - Settings

enum EdgeAction: String, CaseIterable, Identifiable {
    case off, volume, brightness
    var id: String { rawValue }
    var title: String {
        switch self {
        case .off: return "Off"
        case .volume: return "Volume"
        case .brightness: return "Brightness"
        }
    }
}

final class Settings: ObservableObject {
    static let shared = Settings()
    private let d = UserDefaults.standard

    @Published var enabled: Bool { didSet { d.set(enabled, forKey: "enabled") } }
    @Published var edgePercent: Double { didSet { d.set(edgePercent, forKey: "edgePercent") } }
    @Published var sensitivity: Double { didSet { d.set(sensitivity, forKey: "sensitivity") } }
    @Published var requireOption: Bool { didSet { d.set(requireOption, forKey: "requireOption") } }
    @Published var showHUD: Bool { didSet { d.set(showHUD, forKey: "showHUD") } }
    @Published var leftAction: EdgeAction { didSet { d.set(leftAction.rawValue, forKey: "leftAction") } }
    @Published var rightAction: EdgeAction { didSet { d.set(rightAction.rawValue, forKey: "rightAction") } }
    @Published var bottomAction: EdgeAction { didSet { d.set(bottomAction.rawValue, forKey: "bottomAction") } }
    @Published var launchAtLogin: Bool {
        didSet {
            do {
                if launchAtLogin { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch { NSLog("EdgeSlide: login item error: \(error)") }
        }
    }

    init() {
        enabled = d.object(forKey: "enabled") as? Bool ?? true
        edgePercent = d.object(forKey: "edgePercent") as? Double ?? 8
        sensitivity = d.object(forKey: "sensitivity") as? Double ?? 1.0
        requireOption = d.object(forKey: "requireOption") as? Bool ?? false
        showHUD = d.object(forKey: "showHUD") as? Bool ?? true
        leftAction = EdgeAction(rawValue: d.string(forKey: "leftAction") ?? "") ?? .brightness
        rightAction = EdgeAction(rawValue: d.string(forKey: "rightAction") ?? "") ?? .volume
        bottomAction = EdgeAction(rawValue: d.string(forKey: "bottomAction") ?? "") ?? .off
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func action(for zone: TouchEngine.Zone) -> EdgeAction {
        switch zone {
        case .left: return leftAction
        case .right: return rightAction
        case .bottom: return bottomAction
        }
    }
}

// MARK: - Volume / Brightness

enum Levels {
    static func get(_ a: EdgeAction) -> Double {
        switch a {
        case .volume: return Volume.get()
        case .brightness: return Brightness.get()
        case .off: return 0
        }
    }
    static func set(_ a: EdgeAction, _ v: Double) {
        switch a {
        case .volume: Volume.set(v)
        case .brightness: Brightness.set(v)
        case .off: break
        }
    }
}

enum Volume {
    private static func device() -> AudioDeviceID? {
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        let st = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id)
        return (st == noErr && id != 0) ? id : nil
    }

    // 'vmvc' = virtual main volume
    private static func volAddr() -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: 0x766D7663,
                                   mScope: kAudioDevicePropertyScopeOutput,
                                   mElement: kAudioObjectPropertyElementMain)
    }

    static func get() -> Double {
        guard let dev = device() else { return 0 }
        var addr = volAddr()
        var v: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        AudioObjectGetPropertyData(dev, &addr, 0, nil, &size, &v)
        return Double(v)
    }

    static func set(_ value: Double) {
        guard let dev = device() else { return }
        var addr = volAddr()
        var v = Float32(max(0, min(1, value)))
        AudioObjectSetPropertyData(dev, &addr, 0, nil, UInt32(MemoryLayout<Float32>.size), &v)
        if v > 0 {  // unmute when raising
            var maddr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute,
                                                   mScope: kAudioDevicePropertyScopeOutput,
                                                   mElement: kAudioObjectPropertyElementMain)
            var m: UInt32 = 0
            AudioObjectSetPropertyData(dev, &maddr, 0, nil, UInt32(MemoryLayout<UInt32>.size), &m)
        }
    }
}

enum Brightness {
    private typealias GetFn = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetFn = @convention(c) (UInt32, Float) -> Int32

    private static let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)
    private static let getFn: GetFn? = {
        guard let h = handle, let s = dlsym(h, "DisplayServicesGetBrightness") else { return nil }
        return unsafeBitCast(s, to: GetFn.self)
    }()
    private static let setFn: SetFn? = {
        guard let h = handle, let s = dlsym(h, "DisplayServicesSetBrightness") else { return nil }
        return unsafeBitCast(s, to: SetFn.self)
    }()

    private static func display() -> UInt32 {
        var ids = [CGDirectDisplayID](repeating: 0, count: 8)
        var n: UInt32 = 0
        CGGetActiveDisplayList(8, &ids, &n)
        for i in 0..<Int(n) where CGDisplayIsBuiltin(ids[i]) != 0 { return ids[i] }
        return CGMainDisplayID()
    }

    static func get() -> Double {
        var v: Float = 0
        _ = getFn?(display(), &v)
        return Double(v)
    }

    static func set(_ value: Double) {
        _ = setFn?(display(), Float(max(0, min(1, value))))
    }
}

// MARK: - HUD

final class HUDModel: ObservableObject {
    @Published var level: Double = 0
    @Published var action: EdgeAction = .volume
}

struct HUDView: View {
    @ObservedObject var model: HUDModel

    var icon: String {
        if model.action == .brightness { return "sun.max.fill" }
        if model.level <= 0.001 { return "speaker.slash.fill" }
        if model.level < 0.34 { return "speaker.wave.1.fill" }
        if model.level < 0.67 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 20)).frame(width: 30)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.2))
                    Capsule().fill(Color.primary.opacity(0.85))
                        .frame(width: max(6, g.size.width * CGFloat(model.level)))
                }
            }
            .frame(height: 8)
            Text("\(Int((model.level * 100).rounded()))%")
                .font(.system(size: 14, weight: .medium).monospacedDigit())
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .frame(width: 280, height: 56)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

final class HUD {
    static let shared = HUD()
    private let model = HUDModel()
    private var panel: NSPanel?
    private var hideWork: DispatchWorkItem?

    private func makePanel() -> NSPanel {
        let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 280, height: 56),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.level = .statusBar
        p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        let host = NSHostingView(rootView: HUDView(model: model))
        host.frame = NSRect(x: 0, y: 0, width: 280, height: 56)
        p.contentView = host
        return p
    }

    func show(_ action: EdgeAction, _ level: Double) {
        guard Settings.shared.showHUD else { return }
        hideWork?.cancel()
        model.action = action
        model.level = level
        if panel == nil { panel = makePanel() }
        guard let p = panel else { return }
        if let sf = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame {
            p.setFrameOrigin(NSPoint(x: sf.midX - 140, y: sf.minY + 80))
        }
        if !p.isVisible { p.alphaValue = 1; p.orderFrontRegardless() } else { p.alphaValue = 1 }
    }

    func scheduleHide() {
        hideWork?.cancel()
        let w = DispatchWorkItem { [weak self] in
            guard let p = self?.panel else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.25
                p.animator().alphaValue = 0
            }, completionHandler: { p.orderOut(nil) })
        }
        hideWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: w)
    }
}

// MARK: - Trackpad touch engine (MultitouchSupport private framework)

private typealias MTCallback = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32
private typealias MTListFn = @convention(c) () -> Unmanaged<CFArray>
private typealias MTRegisterFn = @convention(c) (UnsafeMutableRawPointer, MTCallback) -> Void
private typealias MTStartFn = @convention(c) (UnsafeMutableRawPointer, Int32) -> Int32

private let mtCallback: MTCallback = { _, touches, count, _, _ in
    TouchEngine.shared.handleRaw(touches, Int(count))
    return 0
}

final class TouchEngine {
    static let shared = TouchEngine()
    enum Zone { case left, right, bottom }

    private var devices: NSArray?
    private var blocked = false
    private var zone: Zone?
    private var action: EdgeAction = .off
    private var engaged = false
    private var armPos: Float = 0
    private var startPos: Float = 0
    private var startLevel: Double = 0

    @discardableResult
    func start() -> Bool {
        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let h = dlopen(path, RTLD_NOW),
              let l = dlsym(h, "MTDeviceCreateList"),
              let r = dlsym(h, "MTRegisterContactFrameCallback"),
              let s = dlsym(h, "MTDeviceStart") else { return false }
        let list = unsafeBitCast(l, to: MTListFn.self)
        let reg = unsafeBitCast(r, to: MTRegisterFn.self)
        let startFn = unsafeBitCast(s, to: MTStartFn.self)
        let arr = list().takeRetainedValue() as NSArray
        devices = arr
        for i in 0..<arr.count {
            let dev = Unmanaged.passUnretained(arr[i] as AnyObject).toOpaque()
            reg(dev, mtCallback)
            _ = startFn(dev, 0)
        }
        return arr.count > 0
    }

    // Called on a background multitouch thread
    func handleRaw(_ touches: UnsafeMutableRawPointer?, _ count: Int) {
        var fingers: [(Float, Float)] = []
        if let t = touches {
            for i in 0..<count {
                let b = t + i * 96  // MTTouch struct stride
                let state = b.load(fromByteOffset: 20, as: Int32.self)
                if state == 3 || state == 4 {  // making / touching
                    let x = b.load(fromByteOffset: 32, as: Float.self)
                    let y = b.load(fromByteOffset: 36, as: Float.self)
                    fingers.append((x, y))
                }
            }
        }
        DispatchQueue.main.async { self.process(fingers) }
    }

    private func finish() {
        if engaged { HUD.shared.scheduleHide() }
        engaged = false
        zone = nil
    }

    private func process(_ f: [(Float, Float)]) {
        let s = Settings.shared
        if f.isEmpty { finish(); blocked = false; return }
        guard s.enabled else { return }
        if f.count > 1 { finish(); blocked = true; return }  // multi-finger = normal gesture
        if blocked { return }
        let (x, y) = f[0]

        if zone == nil {  // first frame of a new touch: decide zone once
            let e = Float(s.edgePercent / 100)
            var z: Zone? = nil
            if x <= e { z = .left } else if x >= 1 - e { z = .right } else if y <= e { z = .bottom }
            guard let zz = z else { blocked = true; return }
            let a = s.action(for: zz)
            if a == .off { blocked = true; return }
            zone = zz
            action = a
            armPos = (zz == .bottom) ? x : y
            return
        }

        let pos = (zone == .bottom) ? x : y
        if !engaged {
            if abs(pos - armPos) < 0.02 { return }  // wait for real slide
            if s.requireOption && !NSEvent.modifierFlags.contains(.option) {
                blocked = true; zone = nil; return
            }
            engaged = true
            startPos = pos
            startLevel = Levels.get(action)
        }
        let travel = Float(0.7 / max(0.1, s.sensitivity))
        let lvl = max(0, min(1, startLevel + Double((pos - startPos) / travel)))
        Levels.set(action, lvl)
        HUD.shared.show(action, lvl)
    }
}

// MARK: - Settings UI

struct SettingsView: View {
    @ObservedObject var s = Settings.shared

    var body: some View {
        Form {
            Section {
                Toggle("Enable EdgeSlide", isOn: $s.enabled)
                Toggle("Launch at login", isOn: $s.launchAtLogin)
            }
            Section("Edges") {
                Picker("Left edge", selection: $s.leftAction) {
                    ForEach(EdgeAction.allCases) { Text($0.title).tag($0) }
                }
                Picker("Right edge", selection: $s.rightAction) {
                    ForEach(EdgeAction.allCases) { Text($0.title).tag($0) }
                }
                Picker("Bottom edge (left-right slide)", selection: $s.bottomAction) {
                    ForEach(EdgeAction.allCases) { Text($0.title).tag($0) }
                }
                VStack(alignment: .leading) {
                    Text("Edge area: \(Int(s.edgePercent))% of trackpad")
                    Slider(value: $s.edgePercent, in: 2...30, step: 1)
                }
            }
            Section("Feel") {
                VStack(alignment: .leading) {
                    Text(String(format: "Sensitivity: %.1f×", s.sensitivity))
                    Slider(value: $s.sensitivity, in: 0.5...2.5, step: 0.1)
                }
                Toggle("Require Option (⌥) key to slide", isOn: $s.requireOption)
                Toggle("Show HUD", isOn: $s.showHUD)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 520)
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var toggleItem: NSMenuItem!
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "hand.draw", accessibilityDescription: "EdgeSlide")

        let menu = NSMenu()
        toggleItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        toggleItem.target = self
        toggleItem.state = Settings.shared.enabled ? .on : .off
        menu.addItem(toggleItem)
        let st = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        st.target = self
        menu.addItem(st)
        menu.addItem(.separator())
        let q = NSMenuItem(title: "Quit EdgeSlide", action: #selector(quit), keyEquivalent: "q")
        q.target = self
        menu.addItem(q)
        statusItem.menu = menu

        if !TouchEngine.shared.start() {
            let a = NSAlert()
            a.messageText = "Trackpad not found"
            a.informativeText = "Could not start MultitouchSupport. If it does not work, allow EdgeSlide in System Settings → Privacy & Security → Input Monitoring, then reopen the app."
            a.runModal()
        }
    }

    @objc func toggleEnabled() {
        Settings.shared.enabled.toggle()
        toggleItem.state = Settings.shared.enabled ? .on : .off
    }

    @objc func openSettings() {
        if settingsWindow == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            w.title = "EdgeSlide Settings"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            settingsWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc func quit() { NSApp.terminate(nil) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
