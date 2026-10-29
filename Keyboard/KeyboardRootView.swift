import SwiftUI

struct KeyboardRootView: View {
    static let space = "keyboard"
    @ObservedObject var state: KeyboardState

    var body: some View {
        GeometryReader { geo in
            let pad = geo.size.width > 600
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    TopBarView(state: state, pad: pad)
                        .frame(height: pad ? 46 : 40)
                    content(pad: pad)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                StatusToast(state: state)
                PopupOverlay(popup: state.popup, accent: state.settings.accent.color, pad: pad)
            }
            .coordinateSpace(name: Self.space)
            .onAppear { state.popup.containerSize = geo.size }
            .onChange(of: geo.size) { _, size in state.popup.containerSize = size }
        }
        .tint(state.settings.accent.color)
    }

    @ViewBuilder private func content(pad: Bool) -> some View {
        switch state.screen {
        case .keys(let page):
            KeysLayoutView(state: state, page: page)
        case .panel(let panel):
            PanelContainer(state: state, panel: panel, pad: pad)
        case .wizard:
            WizardView(state: state, pad: pad)
        }
    }
}

/// Short-lived messages ("Copied", symbol names…) shown at the bottom of the keyboard.
struct StatusToast: View {
    @ObservedObject var state: KeyboardState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack {
            Spacer()
            if !state.status.isEmpty {
                Text(state.status)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(.regularMaterial))
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 1)
                    .padding(.bottom, 60)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: state.status)
        .allowsHitTesting(false)
    }
}

// MARK: - Top bar

struct TopBarView: View {
    @ObservedObject var state: KeyboardState
    let pad: Bool

    var body: some View {
        Group {
            switch state.sink {
            case .search?: SearchBar(state: state)
            case .wizardField?: WizardFieldBar(state: state)
            case .molar?: MolarFieldBar(state: state)
            case nil:
                if case .keys = state.screen {
                    TypingBar(state: state, pad: pad)
                } else {
                    PanelBar(state: state, pad: pad)
                }
            }
        }
        .padding(.horizontal, 6)
    }
}

struct BarChip: View {
    let text: String
    var selected = false
    var accent = false
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = KeyPalette(scheme)
        Button(action: action) {
            Text(text)
                .font(.system(size: 15, weight: selected || accent ? .semibold : .regular))
                .lineLimit(1)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .foregroundColor(selected ? .white : p.text)
                .background(
                    Capsule().fill(selected ? Color.accentColor : (accent ? p.letter : p.chip))
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct BarIconButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .frame(width: 38, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Shown while typing: science menu button, suggestion slots, language and search.
struct TypingBar: View {
    @ObservedObject var state: KeyboardState
    let pad: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = KeyPalette(scheme)
        HStack(spacing: 6) {
            BarIconButton(icon: "square.grid.2x2") {
                state.feedback()
                state.openPanel(state.lastPanel)
            }
            if let mode = state.scriptMode {
                BarChip(text: "\(mode.short) ✕", accent: true) { state.scriptMode = nil }
            }
            if let style = state.alphabet {
                BarChip(text: "\(style.apply(to: "A")) ✕", accent: true) { state.alphabet = nil }
            }
            HStack(spacing: 0) {
                ForEach(Array(state.suggestions.enumerated()), id: \.element.id) { index, s in
                    if index > 0 {
                        Rectangle().fill(p.secondaryText.opacity(0.35)).frame(width: 1, height: 22)
                    }
                    Button {
                        state.applySuggestion(s)
                    } label: {
                        Text(s.label)
                            .font(.system(size: 17, weight: s.kind == .correction ? .semibold : .regular))
                            .foregroundColor(p.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .padding(.horizontal, 8)
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(s.kind == .correction ? p.letter : Color.clear)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                if state.suggestions.isEmpty { Spacer() }
            }
            .frame(maxWidth: .infinity)
            BarChip(text: state.settings.language.short) { state.cycleLanguage() }
            BarIconButton(icon: "magnifyingglass") {
                state.feedback()
                state.beginSearch()
            }
        }
    }
}

/// Shown in panels: the eight categories.
struct PanelBar: View {
    @ObservedObject var state: KeyboardState
    let pad: Bool

    var body: some View {
        HStack(spacing: 6) {
            BarChip(text: "ABC", accent: true) { state.showPage(.letters) }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(PanelID.allCases) { panel in
                        BarChip(text: pad ? "\(panel.glyph) \(panel.title)" : panel.glyph,
                                selected: state.screen == .panel(panel)) {
                            state.feedback()
                            state.openPanel(panel)
                        }
                    }
                }
            }
            BarIconButton(icon: "magnifyingglass") {
                state.feedback()
                state.beginSearch()
            }
        }
    }
}

struct SearchBar: View {
    @ObservedObject var state: KeyboardState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = KeyPalette(scheme)
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundColor(p.secondaryText)
            Text(state.buffer.isEmpty ? "Search by name, e.g. nabla" : state.buffer + "▏")
                .foregroundColor(state.buffer.isEmpty ? p.secondaryText : p.text)
                .lineLimit(1)
                .frame(minWidth: 80, alignment: .leading)
            Divider().frame(height: 22)
            if !UnicodeIndex.shared.isReady {
                ProgressView().scaleEffect(0.7)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 4) {
                    ForEach(state.searchResults) { entry in
                        Button {
                            state.insertSearchResult(entry)
                        } label: {
                            Text(entry.char.displayForm)
                                .font(.system(size: 22))
                                .frame(minWidth: 36, minHeight: 34)
                                .padding(.horizontal, 2)
                        }
                        .buttonStyle(KeyCapButtonStyle(radius: 6))
                    }
                }
            }
            BarChip(text: "Done", accent: true) { state.closeSink() }
        }
    }
}

struct WizardFieldBar: View {
    @ObservedObject var state: KeyboardState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = KeyPalette(scheme)
        HStack(spacing: 6) {
            BarChip(text: "‹ Back") { state.wizardBack() }
            if let w = state.wizard, let f = w.field {
                VStack(alignment: .leading, spacing: 0) {
                    Text(f.label).font(.system(size: 11)).foregroundColor(p.secondaryText).lineLimit(1)
                    Text(w.fresh ? state.buffer : state.buffer + "▏")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(w.fresh ? p.secondaryText : p.text)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Text(w.preview)
                    .font(.system(size: 17))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundColor(p.text)
                BarChip(text: w.isLast ? "Insert" : "Next ›", accent: true) { state.wizardNext() }
            }
        }
    }
}

struct MolarFieldBar: View {
    @ObservedObject var state: KeyboardState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = KeyPalette(scheme)
        HStack(spacing: 8) {
            Text("Formula:").font(.system(size: 13)).foregroundColor(p.secondaryText)
            Text(state.buffer.isEmpty ? "type e.g. h2so4" : state.buffer + "▏")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(state.buffer.isEmpty ? p.secondaryText : p.text)
                .lineLimit(1)
            Spacer(minLength: 4)
            Group {
                switch state.molarReport {
                case .success(let r):
                    Text("\(state.molarKind.symbol) = \(r.totalText(state.molarPrecision))\(r.unit(state.molarKind, state.molarUnit))")
                        .foregroundColor(p.text)
                case .failure(let e):
                    Text(state.buffer.isEmpty ? "" : e.localizedDescription).foregroundColor(.orange)
                }
            }
            .font(.system(size: 15))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            BarChip(text: "Done", accent: true) { state.closeSink() }
        }
    }
}

// MARK: - Panels

struct PanelContainer: View {
    @ObservedObject var state: KeyboardState
    let panel: PanelID
    let pad: Bool

    /// Panels with their own keypads don't need the space/return row.
    private var showsUtilityRow: Bool {
        switch panel {
        case .calculator: return false
        case .chemistry: return (state.tabs["chem"] ?? 0) >= 2
        default: return true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            panelBody
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if showsUtilityRow {
                UtilityRow(state: state, pad: pad)
                    .frame(height: pad ? 50 : 44)
            }
        }
    }

    @ViewBuilder private var panelBody: some View {
        switch panel {
        case .recents: RecentsPanel(state: state)
        case .symbols: SymbolsPanel(state: state)
        case .chemistry: ChemistryPanel(state: state, pad: pad)
        case .physics: PhysicsPanel(state: state)
        case .calculator: CalculatorPanel(state: state, pad: pad)
        case .clipboard: ClipboardPanel(state: state)
        case .builders: PresetsPanel(state: state)
        case .tools: ToolsPanel(state: state, pad: pad)
        }
    }
}

/// Header row of a panel: tabs on the left, optional actions on the right.
struct PanelHeader<Trailing: View>: View {
    @ObservedObject var state: KeyboardState
    var tabs: [String] = []
    var tabKey: String = ""
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 8) {
            if !tabs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    SegmentTabs(titles: tabs, selection: state.tabBinding(tabKey))
                }
            } else {
                Spacer()
            }
            trailing()
        }
        .padding(.horizontal, 8)
        .frame(height: 36)
    }
}

extension PanelHeader where Trailing == EmptyView {
    init(state: KeyboardState, tabs: [String] = [], tabKey: String = "") {
        self.init(state: state, tabs: tabs, tabKey: tabKey, trailing: { EmptyView() })
    }
}

struct SegmentTabs: View {
    let titles: [String]
    @Binding var selection: Int
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = KeyPalette(scheme)
        HStack(spacing: 2) {
            ForEach(Array(titles.enumerated()), id: \.offset) { i, title in
                Button {
                    selection = i
                } label: {
                    Text(title)
                        .font(.system(size: 13, weight: selection == i ? .semibold : .regular))
                        .lineLimit(1)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .foregroundColor(p.text)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(selection == i ? p.letter : Color.clear)
                                .shadow(color: selection == i ? p.shadow.opacity(0.6) : .clear, radius: 0, y: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(p.chip))
        .fixedSize()
    }
}

struct SmallButton: View {
    let title: String
    var icon: String? = nil
    var selected = false
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon { Image(systemName: icon) }
                Text(title).lineLimit(1)
            }
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .buttonStyle(KeyCapButtonStyle(kind: .function, selected: selected, radius: 7))
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }
}

struct SymbolCell: View {
    let symbol: String
    let state: KeyboardState
    @State private var longFired = false

    var body: some View {
        Button {
            if longFired { longFired = false; return }
            state.feedback()
            state.insertSymbol(symbol)
        } label: {
            Text(symbol.displayForm)
                .font(.system(size: symbol.count > 2 ? 15 : 22))
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .padding(.horizontal, 3)
                .frame(maxWidth: .infinity, minHeight: 40)
        }
        .buttonStyle(KeyCapButtonStyle(radius: 6))
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                longFired = true
                state.toggleFavorite(symbol)
            }
        )
    }
}

struct SymbolGrid: View {
    let state: KeyboardState
    let sections: [SymbolSection]
    var minCell: CGFloat = 44
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = KeyPalette(scheme)
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                if sections.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(sections) { section in
                                Button {
                                    withAnimation { proxy.scrollTo(section.id, anchor: .top) }
                                } label: {
                                    Text(section.title)
                                        .font(.system(size: 12))
                                        .lineLimit(1)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .foregroundColor(p.text)
                                        .background(Capsule().fill(p.chip))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                    .frame(height: 28)
                }
                ScrollView(.vertical) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: minCell), spacing: 6)],
                              spacing: 6, pinnedViews: [.sectionHeaders]) {
                        ForEach(sections) { section in
                            Section {
                                ForEach(Array(section.items.enumerated()), id: \.offset) { _, item in
                                    SymbolCell(symbol: item, state: state)
                                }
                            } header: {
                                Text(section.title.uppercased())
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(p.header)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 4)
                                    .background(.regularMaterial)
                                    .id(section.id)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
                }
            }
        }
    }
}
