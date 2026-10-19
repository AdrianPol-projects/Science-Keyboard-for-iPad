import Foundation

enum ElementCategory: String, CaseIterable, Identifiable {
    case alkaliMetal, alkalineEarth, transitionMetal, postTransition, metalloid, nonmetal
    case halogen, nobleGas, lanthanide, actinide

    var id: String { rawValue }

    var title: String {
        switch self {
        case .alkaliMetal: return "Alkali metal"
        case .alkalineEarth: return "Alkaline earth metal"
        case .transitionMetal: return "Transition metal"
        case .postTransition: return "Post-transition metal"
        case .metalloid: return "Metalloid"
        case .nonmetal: return "Reactive nonmetal"
        case .halogen: return "Halogen"
        case .nobleGas: return "Noble gas"
        case .lanthanide: return "Lanthanide"
        case .actinide: return "Actinide"
        }
    }

    /// sRGB components so both targets can build their own Color.
    var rgb: (Double, Double, Double) {
        switch self {
        case .alkaliMetal: return (0.96, 0.45, 0.42)
        case .alkalineEarth: return (0.98, 0.66, 0.36)
        case .transitionMetal: return (0.96, 0.82, 0.38)
        case .postTransition: return (0.55, 0.80, 0.55)
        case .metalloid: return (0.40, 0.78, 0.72)
        case .nonmetal: return (0.38, 0.66, 0.95)
        case .halogen: return (0.52, 0.55, 0.96)
        case .nobleGas: return (0.75, 0.52, 0.94)
        case .lanthanide: return (0.94, 0.52, 0.78)
        case .actinide: return (0.86, 0.47, 0.60)
        }
    }
}

struct Element: Identifiable, Hashable {
    let number: Int
    let symbol: String
    let name: String
    let mass: Double
    let massText: String
    let synthetic: Bool
    let massNumber: Int
    let period: Int
    let group: Int?
    let row: Int
    let column: Int
    let category: ElementCategory

    var id: Int { number }

    var nuclide: String {
        Scripts.superscript(String(massNumber)) + Scripts.subscripted(String(number)) + symbol
    }

    var configuration: String { ElectronConfiguration.string(for: number) }
    var fullConfiguration: String { ElectronConfiguration.string(for: number, abbreviated: false) }
}

enum PeriodicTable {
    // Z symbol name standard-atomic-weight ([n] = mass number of the most stable isotope)
    private static let data = """
    1 H Hydrogen 1.008
    2 He Helium 4.0026
    3 Li Lithium 6.94
    4 Be Beryllium 9.0122
    5 B Boron 10.81
    6 C Carbon 12.011
    7 N Nitrogen 14.007
    8 O Oxygen 15.999
    9 F Fluorine 18.998
    10 Ne Neon 20.180
    11 Na Sodium 22.990
    12 Mg Magnesium 24.305
    13 Al Aluminium 26.982
    14 Si Silicon 28.085
    15 P Phosphorus 30.974
    16 S Sulfur 32.06
    17 Cl Chlorine 35.45
    18 Ar Argon 39.95
    19 K Potassium 39.098
    20 Ca Calcium 40.078
    21 Sc Scandium 44.956
    22 Ti Titanium 47.867
    23 V Vanadium 50.942
    24 Cr Chromium 51.996
    25 Mn Manganese 54.938
    26 Fe Iron 55.845
    27 Co Cobalt 58.933
    28 Ni Nickel 58.693
    29 Cu Copper 63.546
    30 Zn Zinc 65.38
    31 Ga Gallium 69.723
    32 Ge Germanium 72.630
    33 As Arsenic 74.922
    34 Se Selenium 78.971
    35 Br Bromine 79.904
    36 Kr Krypton 83.798
    37 Rb Rubidium 85.468
    38 Sr Strontium 87.62
    39 Y Yttrium 88.906
    40 Zr Zirconium 91.224
    41 Nb Niobium 92.906
    42 Mo Molybdenum 95.95
    43 Tc Technetium [98]
    44 Ru Ruthenium 101.07
    45 Rh Rhodium 102.91
    46 Pd Palladium 106.42
    47 Ag Silver 107.87
    48 Cd Cadmium 112.41
    49 In Indium 114.82
    50 Sn Tin 118.71
    51 Sb Antimony 121.76
    52 Te Tellurium 127.60
    53 I Iodine 126.90
    54 Xe Xenon 131.29
    55 Cs Caesium 132.91
    56 Ba Barium 137.33
    57 La Lanthanum 138.91
    58 Ce Cerium 140.12
    59 Pr Praseodymium 140.91
    60 Nd Neodymium 144.24
    61 Pm Promethium [145]
    62 Sm Samarium 150.36
    63 Eu Europium 151.96
    64 Gd Gadolinium 157.25
    65 Tb Terbium 158.93
    66 Dy Dysprosium 162.50
    67 Ho Holmium 164.93
    68 Er Erbium 167.26
    69 Tm Thulium 168.93
    70 Yb Ytterbium 173.05
    71 Lu Lutetium 174.97
    72 Hf Hafnium 178.49
    73 Ta Tantalum 180.95
    74 W Tungsten 183.84
    75 Re Rhenium 186.21
    76 Os Osmium 190.23
    77 Ir Iridium 192.22
    78 Pt Platinum 195.08
    79 Au Gold 196.97
    80 Hg Mercury 200.59
    81 Tl Thallium 204.38
    82 Pb Lead 207.2
    83 Bi Bismuth 208.98
    84 Po Polonium [209]
    85 At Astatine [210]
    86 Rn Radon [222]
    87 Fr Francium [223]
    88 Ra Radium [226]
    89 Ac Actinium [227]
    90 Th Thorium 232.04
    91 Pa Protactinium 231.04
    92 U Uranium 238.03
    93 Np Neptunium [237]
    94 Pu Plutonium [244]
    95 Am Americium [243]
    96 Cm Curium [247]
    97 Bk Berkelium [247]
    98 Cf Californium [251]
    99 Es Einsteinium [252]
    100 Fm Fermium [257]
    101 Md Mendelevium [258]
    102 No Nobelium [259]
    103 Lr Lawrencium [266]
    104 Rf Rutherfordium [267]
    105 Db Dubnium [268]
    106 Sg Seaborgium [269]
    107 Bh Bohrium [270]
    108 Hs Hassium [269]
    109 Mt Meitnerium [278]
    110 Ds Darmstadtium [281]
    111 Rg Roentgenium [282]
    112 Cn Copernicium [285]
    113 Nh Nihonium [286]
    114 Fl Flerovium [289]
    115 Mc Moscovium [290]
    116 Lv Livermorium [293]
    117 Ts Tennessine [294]
    118 Og Oganesson [294]
    """

    /// Most abundant isotope where it differs from the rounded atomic weight.
    private static let abundantIsotope: [Int: Int] = [
        28: 58, 29: 63, 30: 64, 31: 69, 32: 74, 34: 80, 35: 79, 40: 90, 42: 98, 44: 102,
        47: 107, 48: 114, 50: 120, 51: 121, 52: 130, 54: 132, 56: 138, 60: 142, 62: 152,
        63: 153, 64: 158, 66: 164, 68: 166, 70: 174, 72: 180, 75: 187, 76: 192, 77: 193,
        80: 202, 81: 205, 82: 208,
    ]

    static let elements: [Element] = data
        .split(separator: "\n")
        .compactMap { line -> Element? in
            let parts = line.split(separator: " ").map(String.init)
            guard parts.count == 4, let z = Int(parts[0]) else { return nil }
            let synthetic = parts[3].hasPrefix("[")
            let massText = parts[3]
            let cleaned = massText.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            let mass = Double(cleaned) ?? 0
            let pos = position(of: z)
            return Element(
                number: z, symbol: parts[1], name: parts[2], mass: mass, massText: massText,
                synthetic: synthetic,
                massNumber: abundantIsotope[z] ?? Int(mass.rounded()),
                period: pos.period, group: pos.group, row: pos.row, column: pos.column,
                category: category(of: z, column: pos.column, fBlock: pos.group == nil))
        }

    private static let bySymbol: [String: Element] = {
        var map: [String: Element] = [:]
        for e in elements { map[e.symbol.lowercased()] = e }
        return map
    }()

    static func element(number: Int) -> Element? {
        guard number >= 1, number <= elements.count else { return nil }
        return elements[number - 1]
    }

    static func element(symbol: String) -> Element? {
        bySymbol[symbol.trimmingCharacters(in: .whitespaces).lowercased()]
    }

    /// Strict lookup (case-sensitive), used for parsing formulas.
    static func isSymbol(_ s: String) -> Bool {
        element(symbol: s)?.symbol == s
    }

    /// 10 rows × 18 columns; row 7 is an empty spacer, rows 8–9 hold the f-block.
    static let grid: [[Element?]] = {
        var g = Array(repeating: Array(repeating: Element?.none, count: 18), count: 10)
        for e in elements { g[e.row][e.column] = e }
        return g
    }()

    static func position(of z: Int) -> (period: Int, group: Int?, row: Int, column: Int) {
        let period: Int
        switch z {
        case ...2: period = 1
        case ...10: period = 2
        case ...18: period = 3
        case ...36: period = 4
        case ...54: period = 5
        case ...86: period = 6
        default: period = 7
        }
        var column = 0
        var fRow: Int?
        switch period {
        case 1:
            column = z == 1 ? 0 : 17
        case 2, 3:
            let offset = z - (period == 2 ? 3 : 11)
            column = offset < 2 ? offset : offset + 10
        case 4, 5:
            column = z - (period == 4 ? 19 : 37)
        default:
            let offset = z - (period == 6 ? 55 : 87)
            if offset < 2 {
                column = offset
            } else if offset < 17 {
                fRow = period == 6 ? 8 : 9
                column = offset + 1
            } else {
                column = offset - 14
            }
        }
        if let r = fRow { return (period, nil, r, column) }
        return (period, column + 1, period - 1, column)
    }

    private static func category(of z: Int, column: Int, fBlock: Bool) -> ElementCategory {
        if fBlock { return z < 87 ? .lanthanide : .actinide }
        if [2, 10, 18, 36, 54, 86, 118].contains(z) { return .nobleGas }
        if [3, 11, 19, 37, 55, 87].contains(z) { return .alkaliMetal }
        if [4, 12, 20, 38, 56, 88].contains(z) { return .alkalineEarth }
        if [9, 17, 35, 53, 85, 117].contains(z) { return .halogen }
        if [5, 14, 32, 33, 51, 52].contains(z) { return .metalloid }
        if [1, 6, 7, 8, 15, 16, 34].contains(z) { return .nonmetal }
        if (2...11).contains(column) { return .transitionMetal }
        return .postTransition
    }
}

// MARK: - Electron configuration

enum ElectronConfiguration {
    private static let order: [(n: Int, l: Int)] = [
        (1, 0), (2, 0), (2, 1), (3, 0), (3, 1), (4, 0), (3, 2), (4, 1), (5, 0), (4, 2), (5, 1),
        (6, 0), (4, 3), (5, 2), (6, 1), (7, 0), (5, 3), (6, 2), (7, 1),
    ]
    private static let letters: [Character] = ["s", "p", "d", "f"]
    private static let nobleGases: [(z: Int, symbol: String)] = [
        (2, "He"), (10, "Ne"), (18, "Ar"), (36, "Kr"), (54, "Xe"), (86, "Rn"),
    ]

    /// Ground-state anomalies, written relative to the noble-gas core.
    private static let exceptions: [Int: String] = [
        24: "[Ar] 3d5 4s1", 29: "[Ar] 3d10 4s1",
        41: "[Kr] 4d4 5s1", 42: "[Kr] 4d5 5s1", 44: "[Kr] 4d7 5s1", 45: "[Kr] 4d8 5s1",
        46: "[Kr] 4d10", 47: "[Kr] 4d10 5s1",
        57: "[Xe] 5d1 6s2", 58: "[Xe] 4f1 5d1 6s2", 64: "[Xe] 4f7 5d1 6s2",
        78: "[Xe] 4f14 5d9 6s1", 79: "[Xe] 4f14 5d10 6s1",
        89: "[Rn] 6d1 7s2", 90: "[Rn] 6d2 7s2", 91: "[Rn] 5f2 6d1 7s2", 92: "[Rn] 5f3 6d1 7s2",
        93: "[Rn] 5f4 6d1 7s2", 96: "[Rn] 5f7 6d1 7s2", 103: "[Rn] 5f14 7s2 7p1",
    ]

    private static func key(_ n: Int, _ l: Int) -> Int { n * 10 + l }

    private static func aufbau(_ electrons: Int) -> [Int: Int] {
        var left = electrons
        var occ: [Int: Int] = [:]
        for (n, l) in order where left > 0 {
            let take = min(left, 4 * l + 2)
            occ[key(n, l)] = take
            left -= take
        }
        return occ
    }

    static func occupation(for z: Int) -> [Int: Int] {
        guard let ex = exceptions[z] else { return aufbau(z) }
        let parts = ex.split(separator: " ").map(String.init)
        let coreSymbol = parts[0].trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        let coreZ = nobleGases.first { $0.symbol == coreSymbol }?.z ?? 0
        var occ = aufbau(coreZ)
        for token in parts.dropFirst() {
            let chars = Array(token)
            guard chars.count >= 3, let n = Int(String(chars[0])),
                  let l = letters.firstIndex(of: chars[1]),
                  let count = Int(String(chars[2...])) else { continue }
            occ[key(n, l)] = count
        }
        return occ
    }

    static func string(for z: Int, abbreviated: Bool = true) -> String {
        guard z >= 1 else { return "" }
        let occ = occupation(for: z)
        var core: (z: Int, symbol: String)?
        if abbreviated { core = nobleGases.last { $0.z < z } }
        let coreOcc = core.map { aufbau($0.z) } ?? [:]
        let shells = occ.keys.sorted().compactMap { k -> String? in
            let count = (occ[k] ?? 0) - (coreOcc[k] ?? 0)
            guard count > 0 else { return nil }
            return "\(k / 10)\(letters[k % 10])" + Scripts.superscript(String(count))
        }
        let body = shells.joined(separator: " ")
        guard let c = core else { return body }
        return body.isEmpty ? "[\(c.symbol)]" : "[\(c.symbol)] " + body
    }
}
