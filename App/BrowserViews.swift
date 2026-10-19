import SwiftUI

// MARK: - Symbol browser

struct SymbolBrowserView: View {
    @EnvironmentObject private var model: AppModel
    @State private var query = ""
    @State private var results: [UnicodeEntry] = []
    @State private var indexReady = UnicodeIndex.shared.isReady

    var body: some View {
        List {
            if query.isEmpty {
                Section("Categories") {
                    if !model.favorites.isEmpty {
                        NavigationLink {
                            SymbolGridPage(title: "Favorites", sections: [SymbolSection(id: "fav", title: "Favorites", items: model.favorites)])
                        } label: {
                            Label("Favorites", systemImage: "star.fill")
                        }
                    }
                    ForEach(SymbolCatalog.all) { category in
                        NavigationLink {
                            SymbolGridPage(title: category.title, sections: category.sections)
                        } label: {
                            HStack {
                                Text(category.glyph).frame(width: 36)
                                Text(category.title)
                                Spacer()
                                Text("\(category.sections.reduce(0) { $0 + $1.items.count })")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section("Unicode blocks") {
                    ForEach(SymbolCatalog.blocks) { block in
                        NavigationLink(block.name) {
                            SymbolGridPage(title: block.name, sections: [SymbolSection(id: block.name, title: block.name, items: block.items)])
                        }
                    }
                }
            } else {
                Section(indexReady ? "\(results.count) results" : "Building index…") {
                    ForEach(results) { entry in
                        Button {
                            model.copy(entry.char)
                        } label: {
                            HStack(spacing: 12) {
                                Text(entry.char.displayForm).font(.system(size: 28)).frame(width: 44)
                                VStack(alignment: .leading) {
                                    Text(entry.name.capitalized).font(.subheadline)
                                    Text(entry.char.codepointLabel).font(.caption.monospaced()).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                        .contextMenu { symbolMenu(entry.char) }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Search names, e.g. “integral”, “nabla”, “U+2207”")
        .onChange(of: query) { _, newValue in search(newValue) }
        .onAppear {
            UnicodeIndex.shared.prepare {
                indexReady = true
                search(query)
            }
        }
        .navigationTitle("Symbol browser")
    }

    private func search(_ q: String) {
        results = UnicodeIndex.shared.search(q, limit: 400)
    }

    @ViewBuilder private func symbolMenu(_ s: String) -> some View {
        Button("Copy \(s)") { model.copy(s) }
        Button("Copy code point") { model.copy(s.codepointLabel) }
        Button(model.favorites.contains(s) ? "Remove favorite" : "Add to favorites") { model.toggleFavorite(s) }
    }
}

struct SymbolGridPage: View {
    let title: String
    let sections: [SymbolSection]
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 8)], spacing: 8, pinnedViews: [.sectionHeaders]) {
                ForEach(sections) { section in
                    Section {
                        ForEach(Array(section.items.enumerated()), id: \.offset) { _, item in
                            SymbolTile(symbol: item)
                        }
                    } header: {
                        Text(section.title)
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                            .background(.bar)
                    }
                }
            }
            .padding(.horizontal)
        }
        .navigationTitle(title)
    }
}

struct SymbolTile: View {
    let symbol: String
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Button {
            model.copy(symbol)
        } label: {
            VStack(spacing: 2) {
                Text(symbol.displayForm)
                    .font(.system(size: symbol.count > 2 ? 16 : 28))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                Text(symbol.unicodeName?.capitalized ?? symbol.codepointLabel)
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .padding(4)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
            .overlay(alignment: .topTrailing) {
                if model.favorites.contains(symbol) {
                    Image(systemName: "star.fill").font(.system(size: 8)).foregroundStyle(.yellow).padding(4)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Copy") { model.copy(symbol) }
            Button("Copy code point (\(symbol.codepointLabel))") { model.copy(symbol.codepointLabel) }
            Button(model.favorites.contains(symbol) ? "Remove favorite" : "Add to favorites") { model.toggleFavorite(symbol) }
        }
    }
}

// MARK: - Periodic table

struct PeriodicTableView: View {
    @State private var selected: Element?

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(0..<10, id: \.self) { r in
                    if r == 7 {
                        Spacer().frame(height: 14)
                    } else {
                        HStack(spacing: 4) {
                            ForEach(0..<18, id: \.self) { c in
                                if let e = PeriodicTable.grid[r][c] {
                                    ElementTile(element: e).onTapGesture { selected = e }
                                } else {
                                    Color.clear.frame(width: 64, height: 72)
                                }
                            }
                        }
                    }
                }
                LegendView().padding(.top, 12)
            }
            .padding()
        }
        .navigationTitle("Periodic table")
        .sheet(item: $selected) { e in
            NavigationStack { ElementDetailView(element: e) }
                .presentationDetents([.medium, .large])
        }
    }
}

struct ElementTile: View {
    let element: Element

    var body: some View {
        VStack(spacing: 1) {
            HStack {
                Text("\(element.number)").font(.system(size: 10, weight: .medium))
                Spacer()
            }
            Text(element.symbol).font(.system(size: 22, weight: .bold))
            Text(element.name).font(.system(size: 8)).lineLimit(1).minimumScaleFactor(0.6)
            Text(element.massText).font(.system(size: 8)).foregroundStyle(.black.opacity(0.7))
        }
        .foregroundStyle(.black)
        .padding(4)
        .frame(width: 64, height: 72)
        .background(RoundedRectangle(cornerRadius: 8).fill(element.category.appColor.opacity(0.85)))
    }
}

struct LegendView: View {
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), alignment: .leading)], alignment: .leading, spacing: 6) {
            ForEach(ElementCategory.allCases) { c in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3).fill(c.appColor).frame(width: 14, height: 14)
                    Text(c.title).font(.caption)
                }
            }
        }
        .frame(width: 64 * 18 + 4 * 17, alignment: .leading)
    }
}

struct ElementDetailView: View {
    let element: Element
    @EnvironmentObject private var model: AppModel

    private var rows: [(String, String)] {
        [
            ("Name", element.name),
            ("Symbol", element.symbol),
            ("Atomic number (Z)", "\(element.number)"),
            ("Atomic mass", element.massText + (element.synthetic ? " (most stable isotope)" : "")),
            ("Most common isotope", "\(Scripts.superscript(String(element.massNumber)))\(element.symbol)"),
            ("Group", element.group.map(String.init) ?? "f-block"),
            ("Period", "\(element.period)"),
            ("Category", element.category.title),
            ("Electron configuration", element.configuration),
            ("Full configuration", element.fullConfiguration),
        ]
    }

    private var notations: [(String, String)] {
        let a = String(element.massNumber)
        return [
            ("Nuclide", element.nuclide),
            ("Isotope", Scripts.superscript(a) + element.symbol),
            ("Isotope name", "\(element.name)-\(a)"),
            ("Mass number style", "\(element.symbol)-\(a)"),
            ("Molar mass", "M(\(element.symbol)) = \(element.massText.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))) g·mol⁻¹"),
        ]
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    ElementTile(element: element).scaleEffect(1.6).padding(30)
                    Spacer()
                }
            }
            Section("Properties — tap to copy") {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    Button { model.copy(row.1) } label: {
                        LabeledContent(row.0, value: row.1)
                    }
                    .foregroundStyle(.primary)
                }
            }
            Section("Notations — tap to copy") {
                ForEach(Array(notations.enumerated()), id: \.offset) { _, row in
                    Button { model.copy(row.1) } label: {
                        LabeledContent(row.0) { Text(row.1).font(.title3) }
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
        .navigationTitle(element.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
