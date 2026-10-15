import SwiftUI

// MARK: Rows

struct GraphRow: Identifiable, Codable, Equatable {
    enum Kind: String, Codable { case expression, table }

    var id = UUID()
    var kind: Kind = .expression
    var text = ""
    var colorHex = "007AFF"
    var visible = true
    var fit: RegressionModel = .linear
    var lo: Double = -10
    var hi: Double = 10

    var color: Color {
        get { Color(hex: colorHex) }
        set { colorHex = newValue.hex }
    }
}

struct GraphSlider: Codable, Equatable {
    var value: Double = 1
    var lo: Double = -10
    var hi: Double = 10
}

/// A plottable curve: either `y = f(x)` or an implicit relation `F(x, y) = 0`.
enum Curve {
    case explicit(Expr)
    case implicit(Expr)

    /// Zero exactly on the curve.
    func value(_ x: Double, _ y: Double) -> Double {
        switch self {
        case .explicit(let f): return y - f(x, 0)
        case .implicit(let f): return f(x, y)
        }
    }
}

struct Inequality {
    var holds: Expr // 1 where true
    var boundaries: [(curve: Curve, dashed: Bool)]
}

enum Shape {
    case curve(Curve)
    case inequality(Inequality)
    case parametric(x: Expr, y: Expr, lo: Double, hi: Double)
    case polar(r: Expr, lo: Double, hi: Double)
    case points([(x: Double, y: Double)])
}

struct Drawable: Identifiable {
    let id = UUID()
    var rowID: UUID
    var color: Color
    var shape: Shape
    var explicit: Expr? // set for y = f(x), enabling points of interest
}

enum LineStatus {
    case empty
    case ok
    case error(String)
    case value(String)
    case variable(name: String, value: Double)
    case note(String)
}

struct GraphScene {
    var drawables: [Drawable] = []
    var statuses: [UUID: LineStatus] = [:]
    var freeLetters: [String] = []
}

struct PointOfInterest: Identifiable {
    let id = UUID()
    var x: Double
    var y: Double
    var kind: String
}

// MARK: Text helpers

enum GraphText {
    /// Splits at depth-0 occurrences of any comparison operator.
    static func comparisons(_ text: String) -> (operands: [String], ops: [String]) {
        var operands: [String] = [], ops: [String] = []
        var current = ""
        var depth = 0
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            let ch = chars[i]
            if "([{".contains(ch) { depth += 1 }
            else if ")]}".contains(ch) { depth -= 1 }
            if depth == 0, "<>=≤≥".contains(ch) {
                var op = String(ch)
                if ch == "≤" { op = "<=" }
                if ch == "≥" { op = ">=" }
                if (ch == "<" || ch == ">"), i + 1 < chars.count, chars[i + 1] == "=" { op += "="; i += 1 }
                operands.append(current)
                ops.append(op)
                current = ""
            } else {
                current.append(ch)
            }
            i += 1
        }
        operands.append(current)
        return (operands, ops)
    }

    /// Splits at depth-0 commas.
    static func commaSplit(_ text: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var depth = 0
        for ch in text {
            if "([{".contains(ch) { depth += 1 }
            else if ")]}".contains(ch) { depth -= 1 }
            if depth == 0, ch == "," { parts.append(current); current = "" } else { current.append(ch) }
        }
        parts.append(current)
        return parts
    }

    /// A trailing `{condition}` (without a ':') limits where a line is drawn.
    static func stripRestriction(_ text: String) -> (body: String, restriction: String?) {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard t.hasSuffix("}") else { return (t, nil) }
        let chars = Array(t)
        var depth = 0
        var start: Int?
        for k in stride(from: chars.count - 1, through: 0, by: -1) {
            if chars[k] == "}" { depth += 1 }
            else if chars[k] == "{" { depth -= 1; if depth == 0 { start = k; break } }
        }
        guard let s = start, s > 0 else { return (t, nil) }
        let inner = String(chars[(s + 1)..<(chars.count - 1)])
        guard !inner.contains(":"), inner.contains(where: { "<>=≤≥".contains($0) }) else { return (t, nil) }
        return (String(chars[0..<s]).trimmingCharacters(in: .whitespaces), inner)
    }

    /// If the whole text is `( a , b )`, the two halves.
    static func tuple(_ text: String) -> [String]? {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard t.hasPrefix("("), t.hasSuffix(")") else { return nil }
        // The opening parenthesis must close at the very end.
        var depth = 0
        for (k, ch) in t.enumerated() {
            if ch == "(" { depth += 1 }
            else if ch == ")" { depth -= 1; if depth == 0 && k != t.count - 1 { return nil } }
        }
        let inner = String(t.dropFirst().dropLast())
        let parts = commaSplit(inner)
        return parts.count == 2 ? parts : nil
    }

    static func isFunctionHeader(_ s: String) -> (name: String, params: [String])? {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard let open = t.firstIndex(of: "("), t.hasSuffix(")") else { return nil }
        let name = String(t[..<open])
        guard name.count == 1, let n = name.first, n.isLetter, !"xyeπτφ".contains(n) else { return nil }
        let params = String(t[t.index(after: open)..<t.index(before: t.endIndex)])
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard (1...2).contains(params.count), params.allSatisfy({ $0.count == 1 && $0.first!.isLetter }) else { return nil }
        return (name, params)
    }

    static func isVariableName(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard t.count == 1, let n = t.first, n.isLetter else { return false }
        return !"xyerπτφθ".contains(n)
    }
}

// MARK: Engine

enum GraphEngine {
    private enum Line {
        case empty
        case variable(String, String)               // name, rhs
        case function(String, [String], String)     // name, params, rhs
        case inequality(String, String?)            // body, restriction
        case polar(String, String?)                 // rhs, restriction
        case explicit(String, String?)              // rhs, restriction
        case implicit(String, String, String?)      // lhs, rhs, restriction
        case point(String, String)
        case parametric(String, String, String?)
        case plain(String, String?)
    }

    private struct Entry {
        var row: GraphRow
        var line: Line
    }

    private static func classify(_ raw: String) -> Line {
        let (body, restriction) = GraphText.stripRestriction(raw)
        if body.isEmpty { return .empty }

        if let parts = GraphText.tuple(body) {
            let known = Parser.knownNames(allowY: false)
            let uses = Parser.tokens(parts.joined(separator: " "), known: known)
            if uses.contains("t") { return .parametric(parts[0], parts[1], restriction) }
            return .point(parts[0], parts[1])
        }

        let (operands, ops) = GraphText.comparisons(body)
        if ops.isEmpty { return .plain(body, restriction) }
        if ops.contains(where: { $0 != "=" }) { return .inequality(body, restriction) }
        guard ops.count == 1 else { return .inequality(body, restriction) }

        let lhs = operands[0].trimmingCharacters(in: .whitespaces)
        let rhs = operands[1].trimmingCharacters(in: .whitespaces)
        if let header = GraphText.isFunctionHeader(lhs) { return .function(header.name, header.params, rhs) }
        if lhs == "r" { return .polar(rhs, restriction) }
        if lhs.lowercased() == "y" { return .explicit(rhs, restriction) }
        if GraphText.isVariableName(lhs) {
            let tokens = Parser.tokens(rhs, known: Parser.knownNames())
            if !tokens.contains("x") && !tokens.contains("y") { return .variable(lhs, rhs) }
        }
        return .implicit(lhs, rhs, restriction)
    }

    private static func isConstant(_ f: Expr) -> Bool {
        let a = f(0.37, 0), b = f(1.91, 0)
        return (a.isNaN && b.isNaN) || a == b
    }

    static func compile(rows: [GraphRow], sliders: [String: GraphSlider]) -> GraphScene {
        var scene = GraphScene()
        var entries: [Entry] = []
        for row in rows {
            switch row.kind {
            case .expression:
                entries.append(Entry(row: row, line: classify(row.text)))
            case .table:
                entries.append(Entry(row: row, line: .empty))
            }
        }

        // Names defined by the user are not sliders.
        var definedNames = Set<String>()
        var functionNames = Set<String>()
        for e in entries {
            switch e.line {
            case .variable(let n, _): definedNames.insert(n)
            case .function(let n, _, _): functionNames.insert(n)
            default: break
            }
        }

        var scope = GraphScope()
        for (name, spec) in sliders { scope.variables[name] = spec.value }

        // Free letters (→ sliders).
        func freeLetters(in text: String, extra: [String]) -> Set<String> {
            let known = Parser.knownNames(scope: GraphScope(), allowY: true,
                                          extra: Array(definedNames) + Array(functionNames) + ["t", "θ"] + extra)
            return Parser.unknownLetters(text, known: known)
        }
        var free = Set<String>()
        for e in entries {
            switch e.line {
            case .variable(_, let rhs): free.formUnion(freeLetters(in: rhs, extra: []))
            case .function(_, let params, let rhs): free.formUnion(freeLetters(in: rhs, extra: params))
            case .inequality(let b, let r), .plain(let b, let r), .polar(let b, let r), .explicit(let b, let r):
                free.formUnion(freeLetters(in: b, extra: []))
                if let r { free.formUnion(freeLetters(in: r, extra: [])) }
            case .implicit(let l, let r, let rs):
                free.formUnion(freeLetters(in: l + " " + r, extra: []))
                if let rs { free.formUnion(freeLetters(in: rs, extra: [])) }
            case .point(let a, let b):
                free.formUnion(freeLetters(in: a + " " + b, extra: []))
            case .parametric(let a, let b, let r):
                free.formUnion(freeLetters(in: a + " " + b, extra: []))
                if let r { free.formUnion(freeLetters(in: r, extra: [])) }
            case .empty: break
            }
        }
        scene.freeLetters = free.sorted()
        for name in free where scope.variables[name] == nil { scope.variables[name] = 1 }

        // Definitions may depend on each other, so resolve them over a few passes.
        var failures: [UUID: String] = [:]
        for _ in 0..<4 {
            failures = [:]
            for e in entries {
                switch e.line {
                case .variable(let name, let rhs):
                    if let f = try? Parser.compile2(rhs, angle: .radians, allowY: false, scope: scope) {
                        let v = f(0, 0)
                        if v.isFinite { scope.variables[name] = v } else { failures[e.row.id] = "Not a finite number" }
                    } else {
                        failures[e.row.id] = "Can't read this"
                    }
                case .function(let name, let params, let rhs):
                    var inner = scope
                    inner.bound = [params[0]: .x]
                    if params.count == 2 { inner.bound[params[1]] = .y }
                    inner.functions[name] = nil
                    if let f = try? Parser.compile2(rhs, angle: .radians, allowY: false, scope: inner) {
                        scope.functions[name] = UserFunction(arity: params.count, body: f)
                    } else {
                        failures[e.row.id] = "Can't read this"
                    }
                default: break
                }
            }
        }

        func compile(_ text: String, y: Bool, bound: [String: Parser.Slot] = [:]) -> Expr? {
            var s = scope
            s.bound = bound
            return try? Parser.compile2(text, angle: .radians, allowY: y, scope: s)
        }

        func condition(_ text: String, bound: [String: Parser.Slot] = [:]) -> Expr? {
            let (operands, ops) = GraphText.comparisons(text)
            guard !ops.isEmpty else { return nil }
            var exprs: [Expr] = []
            for o in operands {
                guard let f = compile(o, y: true, bound: bound) else { return nil }
                exprs.append(f)
            }
            let list = exprs, opList = ops
            return { x, y in
                for k in 0..<opList.count {
                    let a = list[k](x, y), b = list[k + 1](x, y)
                    let ok: Bool
                    switch opList[k] {
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

        /// Bounds on a parameter from a restriction such as `0 <= t <= 5`.
        func parameterRange(_ restriction: String?, names: [String], defaults: (Double, Double)) -> (Double, Double) {
            var lo = defaults.0, hi = defaults.1
            guard let restriction else { return (lo, hi) }
            let (operands, ops) = GraphText.comparisons(restriction)
            for (k, o) in operands.enumerated() where names.contains(o.trimmingCharacters(in: .whitespaces)) {
                func value(_ index: Int) -> Double? {
                    guard operands.indices.contains(index), let f = compile(operands[index], y: false) else { return nil }
                    let v = f(0, 0)
                    return v.isFinite ? v : nil
                }
                if k > 0, let v = value(k - 1) {
                    if ops[k - 1].hasPrefix("<") { lo = v } else if ops[k - 1].hasPrefix(">") { hi = v }
                }
                if k < ops.count, let v = value(k + 1) {
                    if ops[k].hasPrefix("<") { hi = v } else if ops[k].hasPrefix(">") { lo = v }
                }
            }
            return (lo, hi)
        }

        for e in entries {
            let row = e.row
            func fail(_ message: String) { scene.statuses[row.id] = .error(message) }
            func add(_ shape: Shape, explicit: Expr? = nil) {
                scene.statuses[row.id] = scene.statuses[row.id] ?? .ok
                if row.visible {
                    scene.drawables.append(Drawable(rowID: row.id, color: row.color, shape: shape, explicit: explicit))
                }
            }
            if let message = failures[row.id] { fail(message); continue }

            switch e.line {
            case .empty:
                if row.kind == .table { compileTable(row, &scene) } else { scene.statuses[row.id] = .empty }

            case .variable(let name, _):
                scene.statuses[row.id] = .variable(name: name, value: scope.variables[name] ?? 0)

            case .function(let name, let params, _):
                scene.statuses[row.id] = .note("\(name)(\(params.joined(separator: ", "))) defined")

            case .plain(let body, let restriction):
                guard let f = compile(body, y: false) else {
                    if compile(body, y: true) != nil { fail("Add an equals sign or an inequality") } else { fail("Can't read this") }
                    continue
                }
                if isConstant(f) {
                    scene.statuses[row.id] = .value("= " + formatNumber(f(0, 0), digits: 10))
                    continue
                }
                var g = f
                if let r = restriction, let cond = condition(r) {
                    g = { x, _ in let v = f(x, 0); return cond(x, v) != 0 ? v : .nan }
                } else if restriction != nil { fail("Can't read the {…} limit"); continue }
                add(.curve(.explicit(g)), explicit: g)

            case .explicit(let rhs, let restriction):
                if let f = compile(rhs, y: false) {
                    var g = f
                    if let r = restriction {
                        guard let cond = condition(r) else { fail("Can't read the {…} limit"); continue }
                        g = { x, _ in let v = f(x, 0); return cond(x, v) != 0 ? v : .nan }
                    }
                    add(.curve(.explicit(g)), explicit: g)
                } else if let f = compile(rhs, y: true) {
                    var g: Expr = { x, y in y - f(x, y) }
                    if let r = restriction, let cond = condition(r) { let h = g; g = { x, y in cond(x, y) != 0 ? h(x, y) : .nan } }
                    add(.curve(.implicit(g)))
                } else {
                    fail("Can't read this")
                }

            case .implicit(let l, let r, let restriction):
                guard let lf = compile(l, y: true), let rf = compile(r, y: true) else { fail("Can't read this"); continue }
                var g: Expr = { x, y in lf(x, y) - rf(x, y) }
                if let rs = restriction {
                    guard let cond = condition(rs) else { fail("Can't read the {…} limit"); continue }
                    let h = g
                    g = { x, y in cond(x, y) != 0 ? h(x, y) : .nan }
                }
                add(.curve(.implicit(g)))

            case .inequality(let body, let restriction):
                guard let holds = condition(body) else { fail("Can't read this"); continue }
                let (operands, ops) = GraphText.comparisons(body)
                var boundaries: [(curve: Curve, dashed: Bool)] = []
                for k in 0..<ops.count {
                    guard let a = compile(operands[k], y: true), let b = compile(operands[k + 1], y: true) else { continue }
                    let boundary: Expr = { x, y in a(x, y) - b(x, y) }
                    boundaries.append((curve: Curve.implicit(boundary), dashed: ops[k] == "<" || ops[k] == ">"))
                }
                var test = holds
                if let rs = restriction {
                    guard let cond = condition(rs) else { fail("Can't read the {…} limit"); continue }
                    test = { x, y in cond(x, y) != 0 && holds(x, y) != 0 ? 1 : 0 }
                }
                add(.inequality(Inequality(holds: test, boundaries: boundaries)))

            case .polar(let rhs, let restriction):
                guard let r = compile(rhs, y: false, bound: ["θ": .y, "t": .y]) else { fail("Can't read this"); continue }
                let range = parameterRange(restriction, names: ["θ", "t"], defaults: (0, 4 * Double.pi))
                add(.polar(r: r, lo: range.0, hi: range.1))

            case .parametric(let a, let b, let restriction):
                let bound: [String: Parser.Slot] = ["t": .y]
                guard let fx = compile(a, y: false, bound: bound), let fy = compile(b, y: false, bound: bound) else {
                    fail("Can't read this"); continue
                }
                let range = parameterRange(restriction, names: ["t"], defaults: (0, 2 * Double.pi))
                add(.parametric(x: fx, y: fy, lo: range.0, hi: range.1))

            case .point(let a, let b):
                guard let fx = compile(a, y: false), let fy = compile(b, y: false) else { fail("Can't read this"); continue }
                let (x, y) = (fx(0, 0), fy(0, 0))
                guard x.isFinite, y.isFinite else { fail("Not a finite point"); continue }
                scene.statuses[row.id] = .value("(\(formatNumber(x, digits: 8)), \(formatNumber(y, digits: 8)))")
                add(.points([(x, y)]))
            }
        }
        return scene
    }

    private static func compileTable(_ row: GraphRow, _ scene: inout GraphScene) {
        let (xs, ys) = Regression.parsePairs(row.text)
        guard !xs.isEmpty else { scene.statuses[row.id] = .empty; return }
        guard row.visible else { scene.statuses[row.id] = .note("\(xs.count) points"); return }
        scene.drawables.append(Drawable(rowID: row.id, color: row.color,
                                        shape: .points(Array(zip(xs, ys)).map { (x: $0.0, y: $0.1) }), explicit: nil))
        guard row.fit != .none else { scene.statuses[row.id] = .note("\(xs.count) points"); return }
        guard let result = Regression.fit(row.fit, xs: xs, ys: ys) else {
            scene.statuses[row.id] = .error("Can't fit \(row.fit.label.lowercased()) to this data")
            return
        }
        scene.statuses[row.id] = .note("\(result.equation)   R² = \(formatNumber(result.r2, digits: 4))")
        let f = result.f
        let g: Expr = { x, _ in f(x) }
        scene.drawables.append(Drawable(rowID: row.id, color: row.color, shape: .curve(.explicit(g)), explicit: g))
    }

    // MARK: Points of interest

    static func pointsOfInterest(of f: Expr, others: [Expr], lo: Double, hi: Double) -> [PointOfInterest] {
        guard lo.isFinite, hi.isFinite, hi > lo else { return [] }
        let n = 600
        let h = (hi - lo) / Double(n)
        let xs = (0...n).map { lo + Double($0) * h }
        let ys = xs.map { f($0, 0) }
        var found: [PointOfInterest] = []
        let tol = (hi - lo) * 1e-6

        func bisect(_ g: (Double) -> Double, _ a0: Double, _ b0: Double) -> Double? {
            var a = a0, b = b0
            var fa = g(a)
            for _ in 0..<60 {
                let m = (a + b) / 2
                let fm = g(m)
                if fm == 0 { a = m; b = m; break }
                if (fa < 0) == (fm < 0) { a = m; fa = fm } else { b = m }
            }
            let x = (a + b) / 2
            let v = g(x)
            return v.isFinite && abs(v) < max(1e-6, abs(f(x, 0)) * 1e-6) * 10 ? x : nil
        }

        // Zeros
        for i in 0..<n {
            let a = ys[i], b = ys[i + 1]
            guard a.isFinite, b.isFinite else { continue }
            if a == 0 { found.append(PointOfInterest(x: xs[i], y: 0, kind: "Zero")) }
            else if a * b < 0, let x = bisect({ f($0, 0) }, xs[i], xs[i + 1]) {
                found.append(PointOfInterest(x: x, y: 0, kind: "Zero"))
            }
        }

        // Extrema
        if n > 2 {
            for i in 1..<n {
                let a = ys[i - 1], b = ys[i], c = ys[i + 1]
                guard a.isFinite, b.isFinite, c.isFinite else { continue }
                let isMax = b > a && b >= c, isMin = b < a && b <= c
                guard isMax || isMin else { continue }
                var l = xs[i - 1], r = xs[i + 1]
                let sign = isMax ? -1.0 : 1.0
                let gr = (5.0.squareRoot() - 1) / 2
                for _ in 0..<70 {
                    let m1 = r - gr * (r - l), m2 = l + gr * (r - l)
                    if sign * f(m1, 0) < sign * f(m2, 0) { r = m2 } else { l = m1 }
                }
                let x = (l + r) / 2, y = f(x, 0)
                guard y.isFinite else { continue }
                // Ignore flat noise and asymptote spikes.
                let scale = max(abs(a), abs(b), abs(c), 1)
                if abs(y - a) < 1e-12 * scale && abs(y - c) < 1e-12 * scale { continue }
                if abs(b) > 1e6 * max(abs(a), abs(c), 1) { continue }
                found.append(PointOfInterest(x: x, y: y, kind: isMax ? "Maximum" : "Minimum"))
            }
        }

        // y-intercept
        if lo <= 0, hi >= 0 {
            let y0 = f(0, 0)
            if y0.isFinite, abs(y0) > 1e-12 { found.append(PointOfInterest(x: 0, y: y0, kind: "Y-intercept")) }
        }

        // Intersections
        for g in others {
            let d = (0...n).map { i -> Double in
                let a = ys[i], b = g(xs[i], 0)
                return a.isFinite && b.isFinite ? a - b : .nan
            }
            for i in 0..<n {
                let a = d[i], b = d[i + 1]
                guard a.isFinite, b.isFinite, a * b <= 0, a != b else { continue }
                if let x = bisect({ f($0, 0) - g($0, 0) }, xs[i], xs[i + 1]) {
                    let y = f(x, 0)
                    if y.isFinite { found.append(PointOfInterest(x: x, y: y, kind: "Intersection")) }
                }
            }
        }

        // De-duplicate, keeping the first of each kind close together.
        var unique: [PointOfInterest] = []
        for p in found where !unique.contains(where: { abs($0.x - p.x) < tol * 100 && $0.kind == p.kind }) {
            unique.append(p)
            if unique.count >= 40 { break }
        }
        return unique
    }
}
