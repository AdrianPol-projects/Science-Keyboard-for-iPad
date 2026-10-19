import SwiftUI
import UIKit

// MARK: - Palette (iOS 18 keyboard colours)

struct KeyPalette {
    let dark: Bool

    init(_ scheme: ColorScheme) { dark = scheme == .dark }

    var letter: Color { dark ? Color(white: 0.42) : .white }
    var function: Color { dark ? Color(white: 0.27) : Color(red: 0.68, green: 0.70, blue: 0.74) }
    var text: Color { dark ? .white : .black }
    var secondaryText: Color { dark ? Color(white: 0.72) : Color(white: 0.45) }
    var shadow: Color { dark ? Color.black.opacity(0.5) : Color(red: 0.52, green: 0.53, blue: 0.56) }
    var popup: Color { dark ? Color(white: 0.42) : .white }
    var chip: Color { dark ? Color.white.opacity(0.12) : Color.black.opacity(0.06) }
    var header: Color { dark ? Color(white: 0.75) : Color(white: 0.35) }
}

extension AccentChoice {
    var color: Color {
        switch self {
        case .blue: return .blue
        case .indigo: return .indigo
        case .purple: return .purple
        case .pink: return .pink
        case .red: return .red
        case .orange: return .orange
        case .green: return .green
        case .teal: return .teal
        }
    }
}

extension ElementCategory {
    var color: Color { Color(red: rgb.0, green: rgb.1, blue: rgb.2) }
}

// MARK: - Key-cap button style used by panels

struct KeyCapButtonStyle: ButtonStyle {
    var kind: KeyKind = .letter
    var selected = false
    var radius: CGFloat = 7

    func makeBody(configuration: Configuration) -> some View {
        KeyCapBody(configuration: configuration, kind: kind, selected: selected, radius: radius)
    }

    private struct KeyCapBody: View {
        let configuration: ButtonStyleConfiguration
        let kind: KeyKind
        let selected: Bool
        let radius: CGFloat
        @Environment(\.colorScheme) private var scheme

        var body: some View {
            let p = KeyPalette(scheme)
            let base: Color = kind == .function ? p.function : p.letter
            let pressedColor: Color = kind == .function ? p.letter : p.function
            configuration.label
                .foregroundColor(selected ? .white : p.text)
                .background(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(selected ? Color.accentColor : (configuration.isPressed ? pressedColor : base))
                        .shadow(color: p.shadow, radius: 0, x: 0, y: 1)
                )
        }
    }
}

// MARK: - Key

struct KeyView: View {
    let spec: KeySpec
    @ObservedObject var state: KeyboardState
    let size: CGSize
    let pad: Bool
    let trailing: Bool

    @Environment(\.colorScheme) private var scheme

    @State private var pressed = false
    @State private var flick = false
    @State private var showAlts = false
    @State private var altIndex = 0
    @State private var longPress: DispatchWorkItem?
    @State private var repeatTimer: Timer?
    @State private var repeatCount = 0
    @State private var cursorMode = false
    @State private var cursorAnchor: CGFloat = 0

    private var palette: KeyPalette { KeyPalette(scheme) }
    private var radius: CGFloat { pad ? 7 : 5 }
    private var altCellWidth: CGFloat { max(min(size.width, 50), 36) }

    var body: some View {
        if spec.kind == .spacer {
            Color.clear.frame(width: max(size.width, 0), height: size.height)
        } else if spec.action == .globe {
            GlobeKey(size: size, radius: radius, palette: palette, controller: state.controller)
        } else {
            cap
                .frame(width: max(size.width, 0), height: size.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged(changed)
                        .onEnded(ended)
                )
                .overlay(alignment: .bottom) { popups }
        }
    }

    // MARK: Appearance

    private var background: Color {
        switch spec.kind {
        case .accent:
            return pressed ? palette.letter : state.settings.accent.color
        case .function:
            return (pressed || spec.highlighted) ? palette.letter : palette.function
        default:
            let darken = pressed && (pad || !state.settings.keyPopups || spec.action == .space)
            return darken ? palette.function : palette.letter
        }
    }

    private var foreground: Color {
        spec.kind == .accent && !pressed ? .white : palette.text
    }

    private var cap: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(background)
                .shadow(color: palette.shadow, radius: 0, x: 0, y: 1)
            label
        }
    }

    @ViewBuilder private var label: some View {
        if let icon = spec.icon {
            Image(systemName: icon)
                .font(.system(size: pad ? 21 : 19, weight: .regular))
                .foregroundColor(foreground)
        } else if let sec = spec.secondary, pad {
            VStack(spacing: 1) {
                Text(sec)
                    .font(.system(size: flick ? 24 : 14))
                    .foregroundColor(flick ? palette.text : palette.secondaryText)
                if !flick {
                    Text(spec.label)
                        .font(.system(size: 22))
                        .foregroundColor(palette.text)
                }
            }
            .animation(.easeOut(duration: 0.08), value: flick)
        } else if spec.action == .space && cursorMode {
            Image(systemName: "arrow.left.and.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(palette.secondaryText)
        } else {
            Text(spec.label)
                .font(spec.kind == .letter && spec.action != .space
                      ? .system(size: 23)
                      : .system(size: pad ? 18 : 16))
                .foregroundColor(foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .padding(.horizontal, 2)
        }
    }

    @ViewBuilder private var popups: some View {
        if showAlts && !spec.alternates.isEmpty {
            alternatesPopup
        } else if pressed && !pad && spec.kind == .letter && spec.action != .space
                    && state.settings.keyPopups && !cursorMode {
            Text(spec.label)
                .font(.system(size: 34))
                .foregroundColor(palette.text)
                .frame(width: size.width + 14, height: size.height * 1.15)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(palette.popup)
                        .shadow(color: .black.opacity(0.28), radius: 2, y: 1)
                )
                .offset(y: -size.height - 4)
                .allowsHitTesting(false)
        }
    }

    private var alternatesPopup: some View {
        let width = CGFloat(spec.alternates.count) * altCellWidth + 8
        return HStack(spacing: 0) {
            ForEach(Array(spec.alternates.enumerated()), id: \.offset) { i, alt in
                Text(alt.displayForm)
                    .font(.system(size: 22))
                    .foregroundColor(i == altIndex ? .white : palette.text)
                    .frame(width: altCellWidth, height: size.height)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(i == altIndex ? state.settings.accent.color : Color.clear)
                    )
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(palette.popup)
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
        )
        .fixedSize()
        .offset(x: trailing ? -(width - size.width) / 2 : (width - size.width) / 2, y: -size.height - 6)
        .allowsHitTesting(false)
    }

    // MARK: Gestures

    private func changed(_ value: DragGesture.Value) {
        if !pressed {
            pressed = true
            touchDown()
        }
        switch spec.action {
        case .space:
            guard state.settings.spaceCursorControl else { return }
            let dx = value.translation.width
            if !cursorMode && abs(dx) > 16 {
                cursorMode = true
                cursorAnchor = dx
                state.feedback()
            }
            if cursorMode {
                let step: CGFloat = pad ? 11 : 8
                let delta = dx - cursorAnchor
                if abs(delta) >= step {
                    let n = Int(delta / step)
                    state.moveCursor(n)
                    cursorAnchor += CGFloat(n) * step
                }
            }
        case .text:
            if showAlts {
                let n = spec.alternates.count
                let popupWidth = CGFloat(n) * altCellWidth + 8
                let origin = (trailing ? size.width - popupWidth : 0) + 4
                let idx = Int(floor((value.location.x - origin) / altCellWidth))
                let clamped = min(max(idx, 0), n - 1)
                if clamped != altIndex { altIndex = clamped }
            } else if pad, spec.secondary != nil, state.settings.flickMode != .off || spec.id == "comma" || spec.id == "period" {
                let isFlick = value.translation.height > 14
                if isFlick != flick {
                    flick = isFlick
                    if isFlick { cancelLongPress() }
                }
            }
        default:
            break
        }
    }

    private func touchDown() {
        state.feedback()
        switch spec.action {
        case .backspace:
            state.deleteBackward()
            repeatCount = 0
            let work = DispatchWorkItem { startRepeat() }
            longPress = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
        case .shift:
            state.tapShift()
        case .text:
            if !spec.alternates.isEmpty {
                let work = DispatchWorkItem {
                    altIndex = 0
                    showAlts = true
                    state.feedback()
                }
                longPress = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.42, execute: work)
            }
        default:
            break
        }
    }

    private func startRepeat() {
        repeatTimer?.invalidate()
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.09, repeats: true) { _ in
            repeatCount += 1
            if repeatCount > 14 {
                if repeatCount % 2 == 0 { state.deleteWord() }
            } else {
                state.deleteBackward()
            }
        }
    }

    private func cancelLongPress() {
        longPress?.cancel()
        longPress = nil
    }

    private func ended(_ value: DragGesture.Value) {
        cancelLongPress()
        repeatTimer?.invalidate()
        repeatTimer = nil
        defer {
            pressed = false
            flick = false
            showAlts = false
            cursorMode = false
        }
        if cursorMode { return }
        if showAlts {
            if spec.alternates.indices.contains(altIndex) {
                state.typeKey(spec.alternates[altIndex], literal: true)
            }
            return
        }
        if flick, let sec = spec.secondary {
            state.typeKey(sec, literal: true)
            return
        }
        switch spec.action {
        case .text(let t): if !t.isEmpty { state.typeKey(t) }
        case .space: state.space()
        case .returnKey: state.returnKey()
        case .page(let p): state.showPage(p)
        case .science: state.toggleScience()
        case .dismiss: state.controller?.dismissKeyboard()
        case .backspace, .shift, .globe: break
        }
    }
}

// MARK: - Globe key (uses the system handler so long-press shows the keyboard list)

struct GlobeKey: View {
    let size: CGSize
    let radius: CGFloat
    let palette: KeyPalette
    weak var controller: KeyboardViewController?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(palette.function)
                .shadow(color: palette.shadow, radius: 0, x: 0, y: 1)
            Image(systemName: "globe")
                .font(.system(size: 20))
                .foregroundColor(palette.text)
            GlobeButton(controller: controller)
        }
        .frame(width: max(size.width, 0), height: size.height)
    }
}

struct GlobeButton: UIViewRepresentable {
    weak var controller: KeyboardViewController?

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .custom)
        if let c = controller {
            button.addTarget(c, action: #selector(UIInputViewController.handleInputModeList(from:with:)), for: .allTouchEvents)
        }
        return button
    }

    func updateUIView(_ uiView: UIButton, context: Context) {}
}

// MARK: - Rows & layout

struct PlacedKey: Identifiable {
    let spec: KeySpec
    let width: CGFloat
    let trailing: Bool
    var id: String { spec.id }
}

struct KeyRowView: View {
    @ObservedObject var state: KeyboardState
    let row: [KeySpec]
    let width: CGFloat
    let height: CGFloat
    let gap: CGFloat
    let pad: Bool

    private var placed: [PlacedKey] {
        let total = row.reduce(CGFloat(0)) { $0 + $1.width }
        let unit = (width + gap) / max(total, 0.01)
        var x: CGFloat = 0
        return row.map { spec in
            let w = unit * spec.width - gap
            let center = x + w / 2
            x += w + gap
            return PlacedKey(spec: spec, width: w, trailing: center > width / 2)
        }
    }

    var body: some View {
        HStack(spacing: gap) {
            ForEach(placed) { key in
                KeyView(spec: key.spec, state: state, size: CGSize(width: key.width, height: height),
                        pad: pad, trailing: key.trailing)
            }
        }
    }
}

struct KeysLayoutView: View {
    @ObservedObject var state: KeyboardState
    let page: KeyPage

    var body: some View {
        GeometryReader { geo in
            let pad = geo.size.width > 600
            let ctx = state.layoutContext(pad: pad)
            let rows = KeyboardLayouts.rows(page: page, ctx: ctx)
            let gap: CGFloat = pad ? 8 : 6
            let rowGap: CGFloat = pad ? 8 : 10
            let hPad: CGFloat = pad ? 5 : 3
            let count = CGFloat(rows.count)
            let rowHeight = max((geo.size.height - rowGap * count) / count, 10)
            VStack(spacing: rowGap) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    KeyRowView(state: state, row: row, width: geo.size.width - 2 * hPad,
                               height: rowHeight, gap: gap, pad: pad)
                        .zIndex(Double(index))
                }
            }
            .padding(.horizontal, hPad)
            .padding(.vertical, rowGap / 2)
        }
    }
}

struct UtilityRow: View {
    @ObservedObject var state: KeyboardState
    let pad: Bool

    var body: some View {
        GeometryReader { geo in
            let gap: CGFloat = pad ? 8 : 6
            let hPad: CGFloat = pad ? 5 : 3
            KeyRowView(state: state, row: KeyboardLayouts.utilityRow(state.layoutContext(pad: pad)),
                       width: geo.size.width - 2 * hPad, height: max(geo.size.height - 8, 10), gap: gap, pad: pad)
                .padding(.horizontal, hPad)
                .padding(.vertical, 4)
        }
    }
}

extension KeyboardState {
    func layoutContext(pad: Bool) -> KeyboardLayouts.Context {
        KeyboardLayouts.Context(pad: pad, shift: shift, flick: settings.flickMode, needsGlobe: needsGlobe,
                                returnLabel: returnLabel, returnPrimary: returnIsPrimary)
    }
}
