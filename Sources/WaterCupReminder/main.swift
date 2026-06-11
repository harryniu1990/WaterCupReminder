import AppKit
import QuartzCore

private enum ReminderSchedule {
    static let startHour = 10
    static let endHour = 18

    static func isActive(_ date: Date = Date()) -> Bool {
        let hour = Calendar.current.component(.hour, from: date)
        return hour >= startHour && hour < endHour
    }

    static func nextReminderDate(after date: Date = Date()) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        let minute = calendar.component(.minute, from: date)
        let second = calendar.component(.second, from: date)
        let hour = components.hour ?? 0

        if isActive(date) {
            if minute == 0 && second == 0 {
                return date
            }
            let nextHour = calendar.date(byAdding: .hour, value: 1, to: calendar.date(from: components) ?? date) ?? date
            if calendar.component(.hour, from: nextHour) < endHour {
                return nextHour
            }
        }

        if hour < startHour {
            return calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: date) ?? date
        }

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        return calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var reminderWindow: ReminderWindow?
    private var triggerTimer: Timer?
    private var guardTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureMenuBar()
        scheduleNextReminder()

        guardTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            if !ReminderSchedule.isActive() {
                self?.dismissReminder()
            }
        }
    }

    private func configureMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "💧"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "现在提醒一次", action: #selector(showReminderNow), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "隐藏水杯", action: #selector(hideReminder), keyEquivalent: "h"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    private func scheduleNextReminder() {
        triggerTimer?.invalidate()
        let nextDate = ReminderSchedule.nextReminderDate()
        triggerTimer = Timer(fireAt: nextDate, interval: 0, target: self, selector: #selector(triggerReminder), userInfo: nil, repeats: false)
        if let triggerTimer {
            RunLoop.main.add(triggerTimer, forMode: .common)
        }
    }

    @objc private func triggerReminder() {
        if ReminderSchedule.isActive() {
            showReminder()
        }
        scheduleNextReminder()
    }

    @objc private func showReminderNow() {
        showReminder()
    }

    @objc private func hideReminder() {
        dismissReminder()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func showReminder() {
        if reminderWindow == nil {
            reminderWindow = ReminderWindow {
                self.dismissReminder()
            }
        }
        reminderWindow?.show()
    }

    private func dismissReminder() {
        reminderWindow?.hide()
    }
}

final class ReminderWindow: NSWindow {
    private let content = WaterCupReminderView(frame: NSRect(x: 0, y: 0, width: 220, height: 260))
    private let onDrink: () -> Void
    private var growTimer: Timer?
    private var currentSize = NSSize(width: 220, height: 260)

    init(onDrink: @escaping () -> Void) {
        self.onDrink = onDrink
        super.init(
            contentRect: NSRect(origin: .zero, size: currentSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        ignoresMouseEvents = false
        contentView = content
        content.onDrink = { [weak self] in
            self?.onDrink()
        }
    }

    func show() {
        currentSize = NSSize(width: 220, height: 260)
        content.progress = 0
        resize(to: currentSize, animated: false)
        positionTopLeft()
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: false)
        content.startAnimating()
        startGrowing()
    }

    func hide() {
        growTimer?.invalidate()
        growTimer = nil
        content.stopAnimating()
        orderOut(nil)
    }

    private func startGrowing() {
        growTimer?.invalidate()
        growTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.grow()
        }
    }

    private func grow() {
        guard let screenFrame = NSScreen.main?.visibleFrame else { return }
        let maxSize = screenFrame.size
        let width = min(maxSize.width, currentSize.width * 1.18)
        let height = min(maxSize.height, currentSize.height * 1.18)
        currentSize = NSSize(width: width, height: height)
        content.progress = min(1, max(width / maxSize.width, height / maxSize.height))
        resize(to: currentSize, animated: true)
        positionTopLeft()
    }

    private func positionTopLeft() {
        guard let screenFrame = NSScreen.main?.visibleFrame else { return }
        let origin = NSPoint(
            x: screenFrame.minX + 18,
            y: screenFrame.maxY - currentSize.height - 18
        )
        setFrame(NSRect(origin: origin, size: currentSize), display: true, animate: false)
    }

    private func resize(to size: NSSize, animated: Bool) {
        guard let screenFrame = NSScreen.main?.visibleFrame else { return }
        let frame = NSRect(
            x: screenFrame.minX + 18,
            y: screenFrame.maxY - size.height - 18,
            width: size.width,
            height: size.height
        )
        setFrame(frame, display: true, animate: animated)
    }
}

final class WaterCupReminderView: NSView {
    var onDrink: (() -> Void)?
    var progress: CGFloat = 0 {
        didSet { needsDisplay = true }
    }

    private let button = NSButton(title: "我喝啦", target: nil, action: nil)
    private var displayLink: Timer?
    private var tick: CGFloat = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        button.bezelStyle = .rounded
        button.font = .systemFont(ofSize: 15, weight: .semibold)
        button.target = self
        button.action = #selector(drinkTapped)
        addSubview(button)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        let buttonWidth = min(bounds.width * 0.46, 150)
        let buttonHeight: CGFloat = 36
        button.frame = NSRect(
            x: (bounds.width - buttonWidth) / 2,
            y: max(18, bounds.height * 0.1),
            width: buttonWidth,
            height: buttonHeight
        )
    }

    func startAnimating() {
        displayLink?.invalidate()
        displayLink = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick += 0.06
            self?.needsDisplay = true
        }
    }

    func stopAnimating() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func drinkTapped() {
        onDrink?()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let pulse = sin(tick) * 0.035 + 1
        let cupWidth = bounds.width * min(0.62, 0.42 + progress * 0.12)
        let cupHeight = bounds.height * min(0.48, 0.38 + progress * 0.08)
        let cupX = (bounds.width - cupWidth) / 2
        let cupY = bounds.height * 0.34 + sin(tick * 1.4) * 5
        let cupRect = NSRect(x: cupX, y: cupY, width: cupWidth, height: cupHeight)

        context.saveGState()
        context.translateBy(x: bounds.midX, y: cupRect.midY)
        context.scaleBy(x: pulse, y: pulse)
        context.translateBy(x: -bounds.midX, y: -cupRect.midY)

        drawSoftGlow(in: context, around: cupRect)
        drawCup(in: context, rect: cupRect)
        drawFace(in: context, rect: cupRect)
        drawBubbles(in: context, rect: cupRect)
        drawMessage(in: context, rect: cupRect)

        context.restoreGState()
    }

    private func drawSoftGlow(in context: CGContext, around rect: NSRect) {
        let glowRect = rect.insetBy(dx: -rect.width * 0.28, dy: -rect.height * 0.22)
        let path = CGPath(ellipseIn: glowRect, transform: nil)
        context.setFillColor(NSColor(calibratedRed: 0.67, green: 0.91, blue: 1.0, alpha: 0.22 + progress * 0.24).cgColor)
        context.addPath(path)
        context.fillPath()
    }

    private func drawCup(in context: CGContext, rect: NSRect) {
        let cupPath = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.16, yRadius: rect.width * 0.16)
        NSColor(calibratedRed: 0.96, green: 0.99, blue: 1.0, alpha: 0.95).setFill()
        cupPath.fill()

        NSColor(calibratedRed: 0.33, green: 0.73, blue: 0.95, alpha: 1).setStroke()
        cupPath.lineWidth = max(4, rect.width * 0.035)
        cupPath.stroke()

        let waterHeight = rect.height * (0.53 + sin(tick * 1.6) * 0.035)
        let waterRect = NSRect(x: rect.minX + rect.width * 0.08, y: rect.minY + rect.height * 0.08, width: rect.width * 0.84, height: waterHeight)
        let waterPath = NSBezierPath(roundedRect: waterRect, xRadius: rect.width * 0.12, yRadius: rect.width * 0.12)
        NSColor(calibratedRed: 0.32, green: 0.78, blue: 1.0, alpha: 0.78).setFill()
        waterPath.fill()

        let rim = NSBezierPath(roundedRect: NSRect(x: rect.minX + rect.width * 0.08, y: rect.maxY - rect.height * 0.14, width: rect.width * 0.84, height: rect.height * 0.12), xRadius: rect.width * 0.1, yRadius: rect.width * 0.1)
        NSColor.white.withAlphaComponent(0.72).setFill()
        rim.fill()

        let handleRect = NSRect(x: rect.maxX - rect.width * 0.05, y: rect.midY - rect.height * 0.18, width: rect.width * 0.28, height: rect.height * 0.34)
        let handle = NSBezierPath(ovalIn: handleRect)
        NSColor(calibratedRed: 0.33, green: 0.73, blue: 0.95, alpha: 1).setStroke()
        handle.lineWidth = max(4, rect.width * 0.035)
        handle.stroke()
    }

    private func drawFace(in context: CGContext, rect: NSRect) {
        let eyeY = rect.midY + rect.height * 0.06
        let eyeRadius = max(5, rect.width * 0.04)
        NSColor(calibratedWhite: 0.14, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: rect.midX - rect.width * 0.18, y: eyeY, width: eyeRadius, height: eyeRadius)).fill()
        NSBezierPath(ovalIn: NSRect(x: rect.midX + rect.width * 0.14, y: eyeY, width: eyeRadius, height: eyeRadius)).fill()

        let smile = NSBezierPath()
        smile.move(to: NSPoint(x: rect.midX - rect.width * 0.08, y: rect.midY - rect.height * 0.05))
        smile.curve(
            to: NSPoint(x: rect.midX + rect.width * 0.08, y: rect.midY - rect.height * 0.05),
            controlPoint1: NSPoint(x: rect.midX - rect.width * 0.035, y: rect.midY - rect.height * 0.13),
            controlPoint2: NSPoint(x: rect.midX + rect.width * 0.035, y: rect.midY - rect.height * 0.13)
        )
        NSColor(calibratedWhite: 0.14, alpha: 1).setStroke()
        smile.lineWidth = max(3, rect.width * 0.02)
        smile.stroke()

        NSColor(calibratedRed: 1.0, green: 0.55, blue: 0.62, alpha: 0.6).setFill()
        NSBezierPath(ovalIn: NSRect(x: rect.midX - rect.width * 0.28, y: rect.midY - rect.height * 0.03, width: rect.width * 0.1, height: rect.height * 0.06)).fill()
        NSBezierPath(ovalIn: NSRect(x: rect.midX + rect.width * 0.18, y: rect.midY - rect.height * 0.03, width: rect.width * 0.1, height: rect.height * 0.06)).fill()
    }

    private func drawBubbles(in context: CGContext, rect: NSRect) {
        for index in 0..<7 {
            let phase = tick * 0.55 + CGFloat(index) * 0.77
            let radius = rect.width * (0.035 + CGFloat(index % 3) * 0.012)
            let xRatio = (0.18 + CGFloat(index) * 0.13).truncatingRemainder(dividingBy: 0.68)
            let x = rect.minX + rect.width * xRatio
            let y = rect.maxY + rect.height * 0.08 + sin(phase) * rect.height * 0.08 + CGFloat(index % 4) * rect.height * 0.09
            let bubble = NSRect(x: x, y: y, width: radius, height: radius)
            NSColor(calibratedRed: 0.42, green: 0.82, blue: 1.0, alpha: 0.45).setFill()
            NSBezierPath(ovalIn: bubble).fill()
        }
    }

    private func drawMessage(in context: CGContext, rect: NSRect) {
        let text = "喝口水吧"
        let fontSize = max(18, min(34, bounds.width * 0.11))
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: NSColor(calibratedRed: 0.05, green: 0.33, blue: 0.48, alpha: 1)
        ]
        let size = text.size(withAttributes: attributes)
        let point = NSPoint(x: (bounds.width - size.width) / 2, y: min(bounds.height - size.height - 14, rect.maxY + 18))
        text.draw(at: point, withAttributes: attributes)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
