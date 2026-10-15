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

/// A user-defined function such as f(x) = x² + 1. Parameters arrive as `(x, y)`.
struct UserFunction {
    var arity: Int
    var body: Expr
}

/// Names a graph line can refer to besides the built-ins.
struct GraphScope {
    var variables: [String: Double] = [:]
    var functions: [String: UserFunction] = [:]
    var bound: [String: Parser.Slot] = [:]
}

/// Recursive-descent parser that compiles an expression into a closure of `x` and `y`.
/// Supports + − × ÷ ^ ! %, parentheses, implicit multiplication, constants (π, e, φ, τ, ∞),
/// the variable `x`, scientific functions, multi-argument functions (nCr, gcd, min, …) and
/// "binder" functions with a bound variable: sum, prod, int, diff, lim.
struct Parser {
    enum Slot { case x, y }

    static let functionNames = [
        "sin", "cos", "tan", "asin", "acos", "atan", "sinh", "cosh", "tanh", "asinh", "acosh", "atanh",
        "sec", "csc", "cot", "ln", "log", "log2", "exp", "exp10", "sqrt", "cbrt", "abs",
        "floor", "ceil", "round", "sign", "gamma", "erf", "fib", "deg", "rad",
    ]
    static let multiArgNames = ["ncr", "npr", "gcd", "lcm", "mod", "min", "max", "avg", "atan2", "hypot", "root", "logb", "rand"]
    static let binderNames = ["sum", "prod", "int", "diff", "lim"]
    static var callNames: [String] { functionNames + multiArgNames + binderNames }
    private static let constantNames = ["pi", "e", "x", "phi", "tau", "inf"]

    private let names: [String]
    private let c: [Character]
    private var i = 0
    private let deg: Bool
    private let angle: AngleMode
    private let allowY: Bool
    private let bound: [String: Slot]
    private let variables: [String: Double]
    private let functions: [String: UserFunction]

    private init(chars: [Character], angle: AngleMode, allowY: Bool, bound: [String: Slot],
                 variables: [String: Double] = [:], functions: [String: UserFunction] = [:]) {
        c = chars
        self.angle = angle
        self.allowY = allowY
        self.bound = bound
        self.variables = variables
        self.functions = functions
        deg = angle == .degrees
        names = Parser.callNames + Parser.constantNames + (allowY ? ["y"] : [])
            + Array(bound.keys) + Array(variables.keys) + Array(functions.keys)
    }

    private static func normalize(_ text: String) -> [Character] {
        var s = text
        let replacements = [
            ("×", "*"), ("÷", "/"), ("−", "-"), ("·", "*"), ("π", "pi"), ("√", "sqrt"), ("∛", "cbrt"),
            ("Σ", "sum"), ("∏", "prod"), ("∫", "int"), ("∞", "inf"), ("φ", "phi"), ("τ", "tau"),
            ("nCr", "ncr"), ("nPr", "npr"), ("≤", "<="), ("≥", ">="),
        ]
        for (a, b) in replacements { s = s.replacingOccurrences(of: a, with: b) }
        return Array(s.filter { !$0.isWhitespace })
    }

    static func compile(_ text: String, angle: AngleMode) throws -> MathFn {
        let e = try compile2(text, angle: angle, allowY: false)
        return { e($0, 0) }
    }

    static func compile2(_ text: String, angle: AngleMode, allowY: Bool, scope: GraphScope = GraphScope()) throws -> Expr {
        try compile(chars: normalize(text), angle: angle, allowY: allowY, bound: scope.bound,
                    variables: scope.variables, functions: scope.functions)
    }

    private static func compile(chars: [Character], angle: AngleMode, allowY: Bool,
                                bound: [String: Slot], variables: [String: Double] = [:],
                                functions: [String: UserFunction] = [:]) throws -> Expr {
        var p = Parser(chars: chars, angle: angle, allowY: allowY, bound: bound,
                       variables: variables, functions: functions)
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
        if ch == "{" { return try piecewise() }
        if ch.isLetter { return try identifier() }
        throw ParseError()
    }

    /// `{cond: value, cond: value, otherwise}`
    private mutating func piecewise() throws -> Expr {
        i += 1
        var branches: [(cond: Expr?, value: Expr)] = []
        while true {
            let save = i
            var cond: Expr?
            if let parsed = try? condition(), peek == ":" {
                i += 1
                cond = parsed
            } else {
                i = save
            }
            let value = try expression()
            branches.append((cond, value))
            if peek == "," { i += 1; continue }
            break
        }
        if peek == "}" { i += 1 } else if i < c.count { throw ParseError() }
        let all = branches
        return { x, y in
            for branch in all {
                if let cond = branch.cond {
                    if cond(x, y) != 0 { return branch.value(x, y) }
                } else {
                    return branch.value(x, y)
                }
            }
            return .nan
        }
    }

    /// `a < b <= c …` evaluating to 1 or 0.
    private mutating func condition() throws -> Expr {
        var operands: [Expr] = [try expression()]
        var ops: [String] = []
        while let op = comparator() {
            ops.append(op)
            operands.append(try expression())
        }
        guard !ops.isEmpty else { throw ParseError() }
        let o = operands, p = ops
        return { x, y in
            for k in 0..<p.count {
                let a = o[k](x, y), b = o[k + 1](x, y)
                let ok: Bool
                switch p[k] {
                case "<": ok = a < b
                case ">": ok = a > b
                case "<=": ok = a <= b
                case ">=": ok = a >= b
                default: ok = abs(a - b) < 1e-9
                }
                if !ok { return 0 }
            }
            return 1
        }
    }

    private mutating func comparator() -> String? {
        guard let ch = peek else { return nil }
        if ch == "<" || ch == ">" {
            if i + 1 < c.count, c[i + 1] == "=" {
                i += 2
                return String(ch) + "="
            }
            i += 1
            return String(ch)
        }
        if ch == "=" {
            i += 1
            return "="
        }
        return nil
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
        if let slot = bound[name] {
            return slot == .x ? { x, _ in x } : { _, y in y }
        }
        if let value = variables[name] { return { _, _ in value } }
        if let fn = functions[name] {
            let args = try argumentList()
            guard args.count == fn.arity, args.count >= 1, args.count <= 2 else { throw ParseError() }
            let body = fn.body
            let a = args[0]
            if args.count == 1 { return { x, y in body(a(x, y), 0) } }
            let b = args[1]
            return { x, y in body(a(x, y), b(x, y)) }
        }
        switch name {
        case "x": return { x, _ in x }
        case "y": return { _, y in y }
        case "pi": return { _, _ in Double.pi }
        case "e": return { _, _ in M_E }
        case "phi": return { _, _ in (1 + 5.0.squareRoot()) / 2 }
        case "tau": return { _, _ in 2 * Double.pi }
        case "inf": return { _, _ in Double.infinity }
        default: break
        }
        if Parser.binderNames.contains(name) { return try binder(name) }

        let d = deg
        if Parser.multiArgNames.contains(name) {
            let list = try argumentList()
            return { x, y in Parser.applyN(name, list.map { $0(x, y) }, deg: d) }
        }

        let arg: Expr
        if peek == "(" { arg = try primary() } else { arg = try power() }
        return { x, y in Parser.apply(name, arg(x, y), deg: d) }
    }

    /// `( a , b , … )`
    private mutating func argumentList() throws -> [Expr] {
        guard peek == "(" else { throw ParseError() }
        i += 1
        var list: [Expr] = []
        if peek == ")" { i += 1; return list }
        while true {
            list.append(try expression())
            if peek == "," { i += 1; continue }
            break
        }
        if peek == ")" { i += 1 } else if i < c.count { throw ParseError() }
        return list
    }

    /// sum / prod / int take `(body, variable, from, to)`; diff and lim take `(body, variable, point)`.
    private mutating func binder(_ name: String) throws -> Expr {
        guard peek == "(" else { throw ParseError() }
        var depth = 0
        var pieces: [[Character]] = []
        var current: [Character] = []
        var j = i + 1
        var closed = false
        while j < c.count {
            let ch = c[j]
            if ch == "(" {
                depth += 1
            } else if ch == ")" {
                if depth == 0 { closed = true; break }
                depth -= 1
            } else if ch == "," && depth == 0 {
                pieces.append(current)
                current = []
                j += 1
                continue
            }
            current.append(ch)
            j += 1
        }
        pieces.append(current)
        i = closed ? j + 1 : c.count

        let needed = (name == "sum" || name == "prod" || name == "int") ? 4 : 3
        guard pieces.count == needed else { throw ParseError() }
        let varName = String(pieces[1])
        guard !varName.isEmpty, varName.allSatisfy({ $0.isLetter }) else { throw ParseError() }

        // The bound variable borrows whichever of the two slots an enclosing binder isn't using.
        let used = Set(bound.values)
        let slot: Slot
        if !used.contains(.y) { slot = .y } else if !used.contains(.x) { slot = .x } else { throw ParseError() }
        var inner = bound
        inner[varName] = slot

        let body = try Parser.compile(chars: pieces[0], angle: angle, allowY: allowY, bound: inner,
                                      variables: variables, functions: functions)
        let lo = try Parser.compile(chars: pieces[2], angle: angle, allowY: allowY, bound: bound,
                                    variables: variables, functions: functions)
        var hi: Expr = { _, _ in 0 }
        if needed == 4 {
            hi = try Parser.compile(chars: pieces[3], angle: angle, allowY: allowY, bound: bound,
                                    variables: variables, functions: functions)
        }
        let upper = hi

        switch name {
        case "sum", "prod":
            let isProduct = name == "prod"
            return { x, y in
                Parser.series(from: lo(x, y), to: upper(x, y), product: isProduct) { k in
                    slot == .y ? body(x, k) : body(k, y)
                }
            }
        case "int":
            return { x, y in
                Parser.integrate(lo(x, y), upper(x, y)) { t in slot == .y ? body(x, t) : body(t, y) }
            }
        case "diff":
            return { x, y in
                Parser.derivative(lo(x, y)) { t in slot == .y ? body(x, t) : body(t, y) }
            }
        default: // lim
            return { x, y in
                Parser.limit(lo(x, y)) { t in slot == .y ? body(x, t) : body(t, y) }
            }
        }
    }

    // MARK: Name scanning (used by the graph to find sliders and parameters)

    static func knownNames(scope: GraphScope = GraphScope(), allowY: Bool = true, extra: [String] = []) -> [String] {
        callNames + constantNames + (allowY ? ["y"] : []) + Array(scope.variables.keys)
            + Array(scope.functions.keys) + Array(scope.bound.keys) + extra
    }

    /// The identifiers in `text`, longest-match first; unrecognized letters come back one at a time.
    static func tokens(_ text: String, known: [String]) -> [String] {
        let chars = normalize(text)
        var out: [String] = []
        var i = 0
        while i < chars.count {
            let ch = chars[i]
            if ch.isLetter {
                let rest = String(chars[i...])
                if let name = known.filter({ rest.hasPrefix($0) }).max(by: { $0.count < $1.count }) {
                    out.append(name)
                    i += name.count
                } else {
                    out.append(String(ch))
                    i += 1
                }
            } else {
                i += 1
            }
        }
        return out
    }

    /// Single lowercase letters in `text` that aren't known names, ignoring the bound variable of sum/prod/int/diff/lim.
    static func unknownLetters(_ text: String, known: [String]) -> Set<String> {
        let knownSet = Set(known)
        let bindings = binderVariables(text)
        return Set(tokens(text, known: known).filter {
            $0.count == 1 && !knownSet.contains($0) && !bindings.contains($0) && ($0.first?.isASCII ?? false)
                && ($0.first?.isLowercase ?? false)
        })
    }

    private static func binderVariables(_ text: String) -> Set<String> {
        let chars = normalize(text)
        var found = Set<String>()
        for name in binderNames {
            let pattern = Array(name + "(")
            var i = 0
            while i + pattern.count <= chars.count {
                if Array(chars[i..<(i + pattern.count)]) == pattern {
                    var depth = 0, commas = 0
                    var piece: [Character] = []
                    var j = i + pattern.count
                    while j < chars.count {
                        let ch = chars[j]
                        if ch == "(" { depth += 1 }
                        else if ch == ")" { if depth == 0 { break }; depth -= 1 }
                        else if ch == "," && depth == 0 { commas += 1; if commas == 2 { break }; j += 1; continue }
                        if commas == 1 { piece.append(ch) }
                        j += 1
                    }
                    let v = String(piece)
                    if !v.isEmpty { found.insert(v) }
                    i = j
                } else {
                    i += 1
                }
            }
        }
        return found
    }

    // MARK: Math

    private static func clean(_ v: Double) -> Double { abs(v) < 1e-12 ? 0 : v }

    static func factorial(_ v: Double) -> Double {
        guard v >= 0, v <= 170 else { return .nan }
        let g = tgamma(v + 1)
        return v == v.rounded() ? g.rounded() : g
    }

    private static func roundSig(_ v: Double, _ digits: Int) -> Double {
        guard v.isFinite, v != 0 else { return v }
        return Double(String(format: "%.\(digits)g", v)) ?? v
    }

    private static func fibonacci(_ v: Double) -> Double {
        guard v == v.rounded(), abs(v) <= 1000 else { return .nan }
        let n = Int(abs(v))
        var a = 0.0, b = 1.0
        for _ in 0..<n { (a, b) = (b, a + b) }
        return v < 0 && n % 2 == 0 ? -a : a
    }

    private static func apply(_ name: String, _ v: Double, deg: Bool) -> Double {
        let k = deg ? Double.pi / 180 : 1
        switch name {
        case "sin": return clean(sin(v * k))
        case "cos": return clean(cos(v * k))
        case "tan":
            if abs(cos(v * k)) < 1e-12 { return .nan }
            return clean(tan(v * k))
        case "sec":
            let c = cos(v * k)
            return abs(c) < 1e-12 ? .nan : 1 / c
        case "csc":
            let s = sin(v * k)
            return abs(s) < 1e-12 ? .nan : 1 / s
        case "cot":
            let s = sin(v * k)
            return abs(s) < 1e-12 ? .nan : cos(v * k) / s
        case "asin": return asin(v) / k
        case "acos": return acos(v) / k
        case "atan": return atan(v) / k
        case "sinh": return sinh(v)
        case "cosh": return cosh(v)
        case "tanh": return tanh(v)
        case "asinh": return asinh(v)
        case "acosh": return acosh(v)
        case "atanh": return atanh(v)
        case "ln": return log(v)
        case "log": return log10(v)
        case "log2": return log2(v)
        case "exp": return exp(v)
        case "exp10": return pow(10, v)
        case "sqrt": return sqrt(v)
        case "cbrt": return cbrt(v)
        case "abs": return abs(v)
        case "floor": return floor(v)
        case "ceil": return ceil(v)
        case "round": return v.rounded()
        case "sign": return v > 0 ? 1 : (v < 0 ? -1 : 0)
        case "gamma": return tgamma(v)
        case "erf": return erf(v)
        case "fib": return fibonacci(v)
        case "deg": return v * 180 / Double.pi
        case "rad": return v * Double.pi / 180
        default: return .nan
        }
    }

    private static func isWhole(_ v: Double) -> Bool { v.isFinite && v == v.rounded() }

    private static func gcd(_ a: Double, _ b: Double) -> Double {
        guard isWhole(a), isWhole(b), abs(a) < 9e15, abs(b) < 9e15 else { return .nan }
        var x = abs(a), y = abs(b)
        while y != 0 { (x, y) = (y, x.truncatingRemainder(dividingBy: y)) }
        return x
    }

    private static func choose(_ n: Double, _ r: Double) -> Double {
        guard isWhole(n), isWhole(r), n >= 0, r >= 0, r <= n, n < 1e6 else { return r > n ? 0 : .nan }
        let k = min(r, n - r)
        var result = 1.0
        var i = 1.0
        while i <= k {
            result = result * (n - k + i) / i
            i += 1
        }
        return result.rounded()
    }

    private static func applyN(_ name: String, _ a: [Double], deg: Bool) -> Double {
        switch name {
        case "ncr": return a.count == 2 ? choose(a[0], a[1]) : .nan
        case "npr":
            guard a.count == 2, isWhole(a[0]), isWhole(a[1]), a[0] >= 0, a[1] >= 0, a[1] <= a[0], a[1] <= 1000 else { return .nan }
            var result = 1.0
            var i = 0.0
            while i < a[1] { result *= a[0] - i; i += 1 }
            return result
        case "gcd": return a.count == 2 ? gcd(a[0], a[1]) : .nan
        case "lcm":
            guard a.count == 2 else { return .nan }
            let g = gcd(a[0], a[1])
            return g == 0 ? 0 : abs(a[0] / g * a[1])
        case "mod":
            guard a.count == 2, a[1] != 0 else { return .nan }
            return a[0] - a[1] * floor(a[0] / a[1])
        case "min": return a.min() ?? .nan
        case "max": return a.max() ?? .nan
        case "avg": return a.isEmpty ? .nan : a.reduce(0, +) / Double(a.count)
        case "atan2":
            guard a.count == 2 else { return .nan }
            let r = atan2(a[0], a[1])
            return deg ? r * 180 / Double.pi : r
        case "hypot": return a.count == 2 ? hypot(a[0], a[1]) : .nan
        case "root":
            guard a.count == 2, a[1] != 0 else { return .nan }
            if a[0] < 0, isWhole(a[1]), Int(a[1]) % 2 != 0 { return -pow(-a[0], 1 / a[1]) }
            return pow(a[0], 1 / a[1])
        case "logb": return a.count == 2 ? log(a[0]) / log(a[1]) : .nan
        case "rand":
            if a.isEmpty { return Double.random(in: 0..<1) }
            if a.count == 2, a[0] < a[1] { return Double.random(in: a[0]..<a[1]) }
            return .nan
        default: return .nan
        }
    }

    // MARK: Numerical calculus

    /// Σ or Π of `term(k)` for whole k from `a` to `b` (b may be ∞ for a converging sum).
    private static func series(from a: Double, to b: Double, product: Bool, term: (Double) -> Double) -> Double {
        guard a.isFinite, !b.isNaN else { return .nan }
        let start = a.rounded(.up)
        var acc = product ? 1.0 : 0.0
        if b == .infinity {
            if product { return .nan }
            var k = start
            var small = 0
            for _ in 0..<2_000_000 {
                let t = term(k)
                acc += t
                if abs(t) <= 1e-16 * max(1, abs(acc)) { small += 1; if small >= 5 { break } } else { small = 0 }
                k += 1
            }
            return roundSig(acc, 12)
        }
        let end = b.rounded(.down)
        guard end.isFinite, end - start < 20_000_000 else { return .nan }
        var k = start
        while k <= end {
            let t = term(k)
            if product { acc *= t } else { acc += t }
            k += 1
        }
        return acc
    }

    // Gauss–Kronrod 15-point rule (nodes strictly inside the interval, so endpoint singularities are fine).
    private static let xgk = [0.991455371120812639206854697526329, 0.949107912342758524526189684047851,
                              0.864864423359769072789712788640926, 0.741531185599394439863864773280788,
                              0.586087235467691130294144838258730, 0.405845151377397166906606412076961,
                              0.207784955007898467600689403773245, 0.0]
    private static let wgk = [0.022935322010529224963732008058970, 0.063092092629978553290700663189204,
                              0.104790010322250183839876322541518, 0.140653259715525918745189590510238,
                              0.169004726639267902826583426598550, 0.190350578064785409913256402421014,
                              0.204432940075298892414161999234649, 0.209482141084727828012999174891714]
    private static let wg = [0.129484966168869693270611432679082, 0.279705391489276667901467771423780,
                             0.381830050505118944950369775488975, 0.417959183673469387755102040816327]

    private static func gaussKronrod(_ f: (Double) -> Double, _ a: Double, _ b: Double) -> (value: Double, error: Double) {
        let c = (a + b) / 2, h = (b - a) / 2
        let fc = f(c)
        var resK = wgk[7] * fc
        var resG = wg[3] * fc
        for j in 0..<7 {
            let dx = h * xgk[j]
            let pair = f(c - dx) + f(c + dx)
            resK += wgk[j] * pair
            if j % 2 == 1 { resG += wg[(j - 1) / 2] * pair }
        }
        return (resK * h, abs((resK - resG) * h))
    }

    private static func adaptive(_ f: (Double) -> Double, _ a: Double, _ b: Double, _ depth: Int) -> Double {
        let r = gaussKronrod(f, a, b)
        if r.error <= max(1e-13, 1e-11 * abs(r.value)) || depth >= 28 { return r.value }
        let m = (a + b) / 2
        return adaptive(f, a, m, depth + 1) + adaptive(f, m, b, depth + 1)
    }

    /// ∫ f from `a` to `b`; either bound may be ±∞.
    private static func integrate(_ a: Double, _ b: Double, _ f: (Double) -> Double) -> Double {
        guard !a.isNaN, !b.isNaN else { return .nan }
        if a == b { return 0 }
        if a > b { return -integrate(b, a, f) }
        let value: Double
        if a == -.infinity && b == .infinity {
            // x = t / (1 − t²)
            value = adaptive({ t in
                let d = 1 - t * t
                return f(t / d) * (1 + t * t) / (d * d)
            }, -1, 1, 0)
        } else if b == .infinity {
            value = adaptive({ t in f(a + t / (1 - t)) / ((1 - t) * (1 - t)) }, 0, 1, 0)
        } else if a == -.infinity {
            value = adaptive({ t in f(b - t / (1 - t)) / ((1 - t) * (1 - t)) }, 0, 1, 0)
        } else {
            value = adaptive(f, a, b, 0)
        }
        return roundSig(value, 11)
    }

    /// Five-point central difference.
    private static func derivative(_ at: Double, _ f: (Double) -> Double) -> Double {
        guard at.isFinite else { return .nan }
        let h = 1e-3 * max(1, abs(at))
        let d = (8 * (f(at + h) - f(at - h)) - (f(at + 2 * h) - f(at - 2 * h))) / (12 * h)
        return roundSig(d, 9)
    }

    /// Two-sided limit estimated from points just either side; ±∞ is probed with large values.
    private static func limit(_ a: Double, _ f: (Double) -> Double) -> Double {
        guard !a.isNaN else { return .nan }
        if a.isInfinite {
            let s = a > 0 ? 1.0 : -1.0
            let v1 = f(s * 1e6), v2 = f(s * 1e9)
            guard v1.isFinite, v2.isFinite, abs(v1 - v2) <= 1e-3 * max(1, abs(v2)) else { return .nan }
            return roundSig(v2, 6)
        }
        let h = 1e-6 * max(1, abs(a))
        let left = f(a - h), right = f(a + h)
        guard left.isFinite, right.isFinite, abs(left - right) <= 1e-4 * max(1, abs(left)) else { return .nan }
        return roundSig((left + right) / 2, 6)
    }
}

func formatNumber(_ v: Double, digits: Int = 12) -> String {
    guard v.isFinite else { return "Error" }
    if v == 0 { return "0" }
    return String(format: "%.\(digits)g", v)
}
