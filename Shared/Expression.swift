import Foundation

enum ExprValue: Equatable {
    case number(Double)
    case string(String)

    var asNumber: Double? {
        switch self {
        case .number(let d): return d
        case .string(let s):
            return Double(s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "−", with: "-"))
        }
    }

    var text: String {
        switch self {
        case .number(let d): return NumberFormat.general(d)
        case .string(let s): return s
        }
    }
}

enum ExprError: LocalizedError {
    case syntax(String)
    case unknown(String)
    case type(String)
    case argument(String)

    var errorDescription: String? {
        switch self {
        case .syntax(let s): return s
        case .unknown(let s): return "Unknown “\(s)”"
        case .type(let s): return s
        case .argument(let s): return "Bad arguments for \(s)()"
        }
    }
}

private enum Token: Equatable {
    case number(Double)
    case ident(String)
    case string(String)
    case op(Character)
    case lparen, rparen, comma
}

/// A small, forgiving math/string expression language.
/// Supports + − × ÷ ^ % !, ² ³, √, implicit multiplication (2π, 3(4+1)),
/// functions, physical constants and string helpers used by presets.
struct ExpressionEvaluator {
    var variables: [String: ExprValue] = [:]
    var degrees = false

    static let constants: [String: Double] = [
        "pi": Double.pi, "π": Double.pi, "e": M_E, "tau": 2 * Double.pi, "τ": 2 * Double.pi,
        "golden": (1 + 5.0.squareRoot()) / 2, "inf": Double.infinity,
        "c": 299_792_458, "h": 6.626_070_15e-34, "hbar": 1.054_571_817e-34, "ℏ": 1.054_571_817e-34,
        "kB": 1.380_649e-23, "NA": 6.022_140_76e23, "R": 8.314_462_618, "F": 96_485.332_12,
        "G": 6.674_30e-11, "g0": 9.806_65, "qe": 1.602_176_634e-19, "me": 9.109_383_7139e-31,
        "mp": 1.672_621_925_95e-27, "mn": 1.674_927_500_56e-27, "u": 1.660_539_068_92e-27,
        "eps0": 8.854_187_8188e-12, "ε0": 8.854_187_8188e-12, "mu0": 1.256_637_061_27e-6,
        "μ0": 1.256_637_061_27e-6, "sigma": 5.670_374_419e-8, "atm": 101_325,
        "a0": 5.291_772_105_44e-11, "Rinf": 10_973_731.568_157, "ly": 9.460_730_472_5808e15,
        "AU": 149_597_870_700, "pc": 3.085_677_581e16,
    ]

    func evaluate(_ source: String) throws -> ExprValue {
        let parser = Parser(tokens: try Self.tokenize(source), evaluator: self)
        let value = try parser.parseExpression()
        guard parser.isAtEnd else { throw ExprError.syntax("Unexpected input") }
        return value
    }

    // MARK: Lexer

    private static func isDigit(_ c: Character) -> Bool { c.isASCII && c.isNumber }

    private static func tokenize(_ s: String) throws -> [Token] {
        var tokens: [Token] = []
        let chars = Array(s)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c.isWhitespace { i += 1; continue }

            if isDigit(c) || (c == "." && i + 1 < chars.count && isDigit(chars[i + 1])) {
                var j = i
                while j < chars.count && (isDigit(chars[j]) || chars[j] == ".") { j += 1 }
                if j < chars.count && (chars[j] == "e" || chars[j] == "E") {
                    var k = j + 1
                    if k < chars.count && (chars[k] == "+" || chars[k] == "-") { k += 1 }
                    if k < chars.count && isDigit(chars[k]) {
                        while k < chars.count && isDigit(chars[k]) { k += 1 }
                        j = k
                    }
                }
                let text = String(chars[i..<j])
                guard let d = Double(text) else { throw ExprError.syntax("Bad number \(text)") }
                tokens.append(.number(d))
                i = j
                continue
            }

            if c == "\"" || c == "“" || c == "”" {
                var j = i + 1
                var str = ""
                while j < chars.count && chars[j] != "\"" && chars[j] != "”" && chars[j] != "“" {
                    str.append(chars[j]); j += 1
                }
                guard j < chars.count else { throw ExprError.syntax("Unclosed string") }
                tokens.append(.string(str))
                i = j + 1
                continue
            }

            if c.isLetter || c == "_" {
                var j = i
                var name = ""
                while j < chars.count {
                    let d = chars[j]
                    if d.isLetter || isDigit(d) || d == "_" {
                        name.append(d); j += 1
                    } else if d == ".", j + 1 < chars.count, chars[j + 1].isLetter {
                        name.append(d); j += 1
                    } else {
                        break
                    }
                }
                tokens.append(.ident(name))
                i = j
                continue
            }

            switch c {
            case "(", "[", "{": tokens.append(.lparen)
            case ")", "]", "}": tokens.append(.rparen)
            case ",", ";": tokens.append(.comma)
            case "+": tokens.append(.op("+"))
            case "-", "−", "–": tokens.append(.op("-"))
            case "*":
                if i + 1 < chars.count && chars[i + 1] == "*" {
                    tokens.append(.op("^")); i += 1
                } else {
                    tokens.append(.op("*"))
                }
            case "×", "·", "⋅", "∙": tokens.append(.op("*"))
            case "/", "÷", "∕", "⁄": tokens.append(.op("/"))
            case "^": tokens.append(.op("^"))
            case "%": tokens.append(.op("%"))
            case "!": tokens.append(.op("!"))
            case "√": tokens.append(.op("√"))
            case "∛": tokens.append(.op("∛"))
            case "²": tokens.append(.op("²"))
            case "³": tokens.append(.op("³"))
            case "∞": tokens.append(.number(.infinity))
            default: throw ExprError.syntax("Unexpected “\(c)”")
            }
            i += 1
        }
        return tokens
    }

    // MARK: Names

    func lookup(_ name: String) throws -> ExprValue {
        if let v = variables[name] { return v }
        if let c = Self.constants[name] { return .number(c) }
        throw ExprError.unknown(name)
    }

    private func elementArg(_ v: ExprValue) -> Element? {
        if case .number(let d) = v { return PeriodicTable.element(number: Int(d.rounded())) }
        if let d = v.asNumber { return PeriodicTable.element(number: Int(d.rounded())) }
        return PeriodicTable.element(symbol: v.text)
    }

    func call(_ rawName: String, _ args: [ExprValue]) throws -> ExprValue {
        func n(_ i: Int) throws -> Double {
            guard i < args.count, let d = args[i].asNumber else { throw ExprError.argument(rawName) }
            return d
        }
        func s(_ i: Int) throws -> String {
            guard i < args.count else { throw ExprError.argument(rawName) }
            return args[i].text
        }
        func el(_ i: Int) throws -> Element {
            guard i < args.count, let e = elementArg(args[i]) else { throw ExprError.argument(rawName) }
            return e
        }
        let k = degrees ? Double.pi / 180 : 1
        let name = rawName.lowercased()
        switch name {
        case "sin": return .number(sin(try n(0) * k))
        case "cos": return .number(cos(try n(0) * k))
        case "tan": return .number(tan(try n(0) * k))
        case "asin", "arcsin": return .number(asin(try n(0)) / k)
        case "acos", "arccos": return .number(acos(try n(0)) / k)
        case "atan", "arctan": return .number(atan(try n(0)) / k)
        case "atan2": return .number(atan2(try n(0), try n(1)) / k)
        case "sinh": return .number(sinh(try n(0)))
        case "cosh": return .number(cosh(try n(0)))
        case "tanh": return .number(tanh(try n(0)))
        case "sqrt": return .number(sqrt(try n(0)))
        case "cbrt": return .number(cbrt(try n(0)))
        case "exp": return .number(exp(try n(0)))
        case "ln": return .number(log(try n(0)))
        case "log":
            if args.count > 1 { return .number(log(try n(0)) / log(try n(1))) }
            return .number(log10(try n(0)))
        case "log2": return .number(log2(try n(0)))
        case "log10": return .number(log10(try n(0)))
        case "abs": return .number(abs(try n(0)))
        case "floor": return .number(floor(try n(0)))
        case "ceil": return .number(ceil(try n(0)))
        case "round":
            let places = try args.count > 1 ? n(1) : 0
            let f = pow(10, places)
            return .number((try n(0) * f).rounded() / f)
        case "min": return .number(try args.indices.map { try n($0) }.min() ?? 0)
        case "max": return .number(try args.indices.map { try n($0) }.max() ?? 0)
        case "fact": return .number(Self.factorial(try n(0)))
        case "ncr":
            let a = try n(0), b = try n(1)
            return .number((Self.factorial(a) / (Self.factorial(b) * Self.factorial(a - b))).rounded())
        case "npr":
            let a = try n(0), b = try n(1)
            return .number((Self.factorial(a) / Self.factorial(a - b)).rounded())
        case "deg": return .number(try n(0) * 180 / Double.pi)
        case "rad": return .number(try n(0) * Double.pi / 180)
        case "mod": return .number(fmod(try n(0), try n(1)))
        case "hypot": return .number(hypot(try n(0), try n(1)))
        // String helpers
        case "sym", "symbol": return .string(try el(0).symbol)
        case "name": return .string(try el(0).name)
        case "z": return .number(Double(try el(0).number))
        case "mass": return .number(try el(0).mass)
        case "config": return .string(try el(0).configuration)
        case "fullconfig": return .string(try el(0).fullConfiguration)
        case "chem": return .string(ChemFormatter.formatText(try s(0)))
        case "sup": return .string(Scripts.superscript(try s(0)))
        case "sub": return .string(Scripts.subscripted(try s(0)))
        case "charge": return .string(Scripts.charge(try s(0)))
        case "sci":
            let digits = try args.count > 1 ? Int(n(1)) : 4
            return .string(NumberFormat.scientific(try n(0), significant: digits))
        case "latex": return .string(LatexConverter.convert(try s(0)))
        case "root":
            let r = Int(try n(0))
            switch r {
            case 2: return .string("√")
            case 3: return .string("∛")
            case 4: return .string("∜")
            default: return .string(Scripts.superscript(String(r)) + "√")
            }
        case "upper": return .string(try s(0).uppercased())
        case "lower": return .string(try s(0).lowercased())
        case "str": return .string(try s(0))
        case "if":
            guard args.count == 3 else { throw ExprError.argument(rawName) }
            let cond = args[0].asNumber.map { $0 != 0 } ?? !args[0].text.isEmpty
            return cond ? args[1] : args[2]
        case "empty": return .number(try s(0).isEmpty ? 1 : 0)
        case "eq":
            guard args.count == 2 else { throw ExprError.argument(rawName) }
            if let a = args[0].asNumber, let b = args[1].asNumber { return .number(a == b ? 1 : 0) }
            return .number(args[0].text == args[1].text ? 1 : 0)
        default:
            throw ExprError.unknown(rawName)
        }
    }

    static func factorial(_ x: Double) -> Double {
        if x < 0 { return .nan }
        if x == x.rounded(), x <= 170 {
            var r = 1.0
            var i = 2.0
            while i <= x { r *= i; i += 1 }
            return r
        }
        return tgamma(x + 1)
    }

    // MARK: Parser

    private final class Parser {
        let tokens: [Token]
        let evaluator: ExpressionEvaluator
        var pos = 0

        init(tokens: [Token], evaluator: ExpressionEvaluator) {
            self.tokens = tokens
            self.evaluator = evaluator
        }

        var isAtEnd: Bool { pos >= tokens.count }
        func peek() -> Token? { pos < tokens.count ? tokens[pos] : nil }
        func advance() -> Token? {
            guard pos < tokens.count else { return nil }
            defer { pos += 1 }
            return tokens[pos]
        }

        func num(_ v: ExprValue) throws -> Double {
            guard let d = v.asNumber else { throw ExprError.type("“\(v.text)” is not a number") }
            return d
        }

        func parseExpression() throws -> ExprValue {
            var lhs = try parseTerm()
            while case .op(let o)? = peek(), o == "+" || o == "-" {
                pos += 1
                let rhs = try parseTerm()
                lhs = try binary(o, lhs, rhs)
            }
            return lhs
        }

        func startsOperand(_ t: Token?) -> Bool {
            switch t {
            case .number?, .ident?, .lparen?: return true
            case .op(let o)?: return o == "√" || o == "∛"
            default: return false
            }
        }

        func parseTerm() throws -> ExprValue {
            var lhs = try parseUnary()
            while true {
                if case .op(let o)? = peek(), o == "*" || o == "/" || o == "%" {
                    pos += 1
                    let rhs = try parseUnary()
                    lhs = try binary(o, lhs, rhs)
                } else if startsOperand(peek()) {
                    let rhs = try parsePower()
                    lhs = try binary("*", lhs, rhs)
                } else {
                    break
                }
            }
            return lhs
        }

        func parseUnary() throws -> ExprValue {
            if case .op(let o)? = peek(), o == "-" || o == "+" {
                pos += 1
                let v = try parseUnary()
                if o == "+" { return v }
                let d = try num(v)
                return .number(-d)
            }
            return try parsePower()
        }

        func parsePower() throws -> ExprValue {
            let base = try parsePostfix()
            if case .op(let o)? = peek(), o == "^" {
                pos += 1
                let exponent = try parseUnary()
                return .number(pow(try num(base), try num(exponent)))
            }
            return base
        }

        func parsePostfix() throws -> ExprValue {
            var v = try parsePrimary()
            while case .op(let o)? = peek(), o == "!" || o == "²" || o == "³" {
                pos += 1
                let x = try num(v)
                switch o {
                case "!": v = .number(ExpressionEvaluator.factorial(x))
                case "²": v = .number(x * x)
                default: v = .number(x * x * x)
                }
            }
            return v
        }

        func parsePrimary() throws -> ExprValue {
            guard let t = advance() else { throw ExprError.syntax("Incomplete expression") }
            switch t {
            case .number(let d):
                return .number(d)
            case .string(let s):
                return .string(s)
            case .lparen:
                let v = try parseExpression()
                if case .rparen? = peek() { pos += 1 }   // forgiving: allow a missing “)” at the end
                else if !isAtEnd { throw ExprError.syntax("Missing )") }
                return v
            case .op(let o) where o == "√" || o == "∛":
                let v = try num(try parsePostfix())
                return .number(o == "√" ? sqrt(v) : cbrt(v))
            case .ident(let name):
                if case .lparen? = peek() {
                    pos += 1
                    var args: [ExprValue] = []
                    if case .rparen? = peek() {
                        pos += 1
                    } else {
                        while true {
                            args.append(try parseExpression())
                            guard let next = advance() else { break }
                            if case .rparen = next { break }
                            guard case .comma = next else { throw ExprError.syntax("Expected , or )") }
                        }
                    }
                    return try evaluator.call(name, args)
                }
                return try evaluator.lookup(name)
            default:
                throw ExprError.syntax("Unexpected symbol")
            }
        }

        func binary(_ o: Character, _ a: ExprValue, _ b: ExprValue) throws -> ExprValue {
            if o == "+" {
                if case .string = a { return .string(a.text + b.text) }
                if case .string = b { return .string(a.text + b.text) }
            }
            let x = try num(a), y = try num(b)
            switch o {
            case "+": return .number(x + y)
            case "-": return .number(x - y)
            case "*": return .number(x * y)
            case "/": return .number(x / y)
            case "%": return .number(fmod(x, y))
            default: throw ExprError.syntax("Bad operator \(o)")
            }
        }
    }
}
