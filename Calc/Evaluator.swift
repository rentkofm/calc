import Foundation

enum AngleMode: String, CaseIterable, Identifiable {
    case degrees, radians
    var id: String { rawValue }
    var label: String { self == .degrees ? "DEG" : "RAD" }
}

typealias MathFn = (Double) -> Double
/// Two-variable expression `(x, y)`, used by the graphing calculator.
typealias Expr = (Double, Double) -> Double

struct ParseError: Error {}

/// Recursive-descent parser that compiles an expression into a closure of `x`.
/// Supports + − × ÷ ^ ! %, parentheses, implicit multiplication,
/// constants (π, e), the variable `x`, and common scientific functions.
struct Parser {
    private static let functionNames = [
        "sin", "cos", "tan", "asin", "acos", "atan", "sinh", "cosh", "tanh",
        "ln", "log", "log2", "sqrt", "cbrt", "abs", "exp", "floor", "ceil", "round"
    ]
    private let names: [String]
    private let c: [Character]
    private var i = 0
    private let deg: Bool

    private init(_ text: String, angle: AngleMode, allowY: Bool) {
        names = Parser.functionNames + ["pi", "e", "x"] + (allowY ? ["y"] : [])
        var s = text
        for (a, b) in [("×", "*"), ("÷", "/"), ("−", "-"), ("·", "*"), ("π", "pi"), ("√", "sqrt"), ("∛", "cbrt")] {
            s = s.replacingOccurrences(of: a, with: b)
        }
        c = Array(s.filter { !$0.isWhitespace })
        deg = angle == .degrees
    }

    static func compile(_ text: String, angle: AngleMode) throws -> MathFn {
        let e = try compile2(text, angle: angle, allowY: false)
        return { e($0, 0) }
    }

    static func compile2(_ text: String, angle: AngleMode, allowY: Bool) throws -> Expr {
        var p = Parser(text, angle: angle, allowY: allowY)
        guard !p.c.isEmpty else { throw ParseError() }
        let f = try p.expression()
        guard p.i == p.c.count else { throw ParseError() }
        return f
    }

    // MARK: Grammar

    private var peek: Character? { i < c.count ? c[i] : nil }

    private mutating func expression() throws -> Expr {
        var lhs = try term()
        while let ch = peek, ch == "+" || ch == "-" {
            i += 1
            let rhs = try term()
            let l = lhs
            lhs = ch == "+" ? { l($0, $1) + rhs($0, $1) } : { l($0, $1) - rhs($0, $1) }
        }
        return lhs
    }

    private mutating func term() throws -> Expr {
        var lhs = try unary()
        while let ch = peek {
            let l = lhs
            if ch == "*" || ch == "/" {
                i += 1
                let rhs = try unary()
                lhs = ch == "*" ? { l($0, $1) * rhs($0, $1) } : { l($0, $1) / rhs($0, $1) }
            } else if ch == "(" || ch == "." || ch.isLetter || ch.isNumber {
                let rhs = try unary() // implicit multiplication
                lhs = { l($0, $1) * rhs($0, $1) }
            } else {
                break
            }
        }
        return lhs
    }

    private mutating func unary() throws -> Expr {
        if let ch = peek, ch == "-" || ch == "+" {
            i += 1
            let f = try unary()
            return ch == "-" ? { -f($0, $1) } : f
        }
        return try power()
    }

    private mutating func power() throws -> Expr {
        let base = try postfix()
        if peek == "^" {
            i += 1
            let exponent = try unary()
            return { pow(base($0, $1), exponent($0, $1)) }
        }
        return base
    }

    private mutating func postfix() throws -> Expr {
        var f = try primary()
        while let ch = peek, ch == "!" || ch == "%" {
            i += 1
            let g = f
            f = ch == "!" ? { Parser.factorial(g($0, $1)) } : { g($0, $1) / 100 }
        }
        return f
    }

    private mutating func primary() throws -> Expr {
        guard let ch = peek else { throw ParseError() }
        if ch.isNumber || ch == "." { return try number() }
        if ch == "(" {
            i += 1
            let f = try expression()
            if peek == ")" { i += 1 } else if i < c.count { throw ParseError() } // auto-close at end
            return f
        }
        if ch.isLetter { return try identifier() }
        throw ParseError()
    }

    private mutating func number() throws -> Expr {
        let start = i
        while let ch = peek, ch.isNumber || ch == "." { i += 1 }
        if let e = peek, e == "e" || e == "E" {
            var j = i + 1
            if j < c.count, c[j] == "+" || c[j] == "-" { j += 1 }
            if j < c.count, c[j].isNumber {
                while j < c.count, c[j].isNumber { j += 1 }
                i = j
            }
        }
        guard let v = Double(String(c[start..<i])) else { throw ParseError() }
        return { _, _ in v }
    }

    private mutating func identifier() throws -> Expr {
        let rest = String(c[i...])
        guard let name = names.filter({ rest.hasPrefix($0) }).max(by: { $0.count < $1.count }) else {
            throw ParseError()
        }
        i += name.count
        switch name {
        case "x": return { x, _ in x }
        case "y": return { _, y in y }
        case "pi": return { _, _ in Double.pi }
        case "e": return { _, _ in M_E }
        default: break
        }
        let arg: Expr
        if peek == "(" { arg = try primary() } else { arg = try power() }
        let d = deg
        return { x, y in Parser.apply(name, arg(x, y), deg: d) }
    }

    // MARK: Math

    private static func clean(_ v: Double) -> Double { abs(v) < 1e-12 ? 0 : v }

    static func factorial(_ v: Double) -> Double {
        guard v >= 0, v <= 170 else { return .nan }
        let g = tgamma(v + 1)
        return v == v.rounded() ? g.rounded() : g
    }

    private static func apply(_ name: String, _ v: Double, deg: Bool) -> Double {
        let k = deg ? Double.pi / 180 : 1
        switch name {
        case "sin": return clean(sin(v * k))
        case "cos": return clean(cos(v * k))
        case "tan":
            if abs(cos(v * k)) < 1e-12 { return .nan }
            return clean(tan(v * k))
        case "asin": return asin(v) / k
        case "acos": return acos(v) / k
        case "atan": return atan(v) / k
        case "sinh": return sinh(v)
        case "cosh": return cosh(v)
        case "tanh": return tanh(v)
        case "ln": return log(v)
        case "log": return log10(v)
        case "log2": return log2(v)
        case "sqrt": return sqrt(v)
        case "cbrt": return cbrt(v)
        case "abs": return abs(v)
        case "exp": return exp(v)
        case "floor": return floor(v)
        case "ceil": return ceil(v)
        case "round": return v.rounded()
        default: return .nan
        }
    }
}

func formatNumber(_ v: Double, digits: Int = 12) -> String {
    guard v.isFinite else { return "Error" }
    if v == 0 { return "0" }
    return String(format: "%.\(digits)g", v)
}
