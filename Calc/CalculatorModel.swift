import SwiftUI
import Observation

struct HistoryItem: Identifiable {
    let id = UUID()
    let expression: String
    let result: String
}

@Observable
final class CalculatorModel {
    var expression = ""
    var preview = ""
    var history: [HistoryItem] = []
    var justEvaluated = false

    private(set) var angle: AngleMode = .degrees
    private(set) var digits = 12

    func configure(angle: AngleMode, digits: Int) {
        self.angle = angle
        self.digits = digits
        refresh()
    }

    private static let continuations: Set<String> = ["+", "−", "×", "÷", "^", "%", "!", "^2", "^(-1)"]
    private static let tokens = [
        "asin(", "acos(", "atan(", "sinh(", "cosh(", "tanh(", "sin(", "cos(", "tan(",
        "ln(", "log(", "log2(", "√(", "∛(", "exp(", "abs(", "("
    ]

    func input(_ s: String) {
        if justEvaluated {
            justEvaluated = false
            if !Self.continuations.contains(s) { expression = "" }
        }
        expression += s
        refresh()
    }

    func clear() {
        expression = ""
        preview = ""
        justEvaluated = false
    }

    func backspace() {
        if justEvaluated { clear(); return }
        if let t = Self.tokens.first(where: { expression.hasSuffix($0) }) {
            expression.removeLast(t.count)
        } else if !expression.isEmpty {
            expression.removeLast()
        }
        refresh()
    }

    func negate() {
        if expression.isEmpty { return }
        justEvaluated = false
        if expression.hasPrefix("-(") && expression.hasSuffix(")") {
            expression = String(expression.dropFirst(2).dropLast())
        } else if expression.hasPrefix("-") {
            expression.removeFirst()
        } else if expression.allSatisfy({ $0.isNumber || $0 == "." }) {
            expression = "-" + expression
        } else {
            expression = "-(" + expression + ")"
        }
        refresh()
    }

    /// Returns false when the expression can't be evaluated.
    @discardableResult
    func equals() -> Bool {
        guard !expression.isEmpty else { return true }
        guard let value = evaluate(), value.isFinite else {
            preview = "Error"
            return false
        }
        let r = formatNumber(value, digits: digits)
        history.insert(HistoryItem(expression: expression, result: r), at: 0)
        expression = r
        preview = ""
        justEvaluated = true
        return true
    }

    func restore(_ item: HistoryItem) {
        expression = item.result
        justEvaluated = true
        preview = ""
    }

    private func evaluate() -> Double? {
        guard let f = try? Parser.compile(expression, angle: angle) else { return nil }
        return f(0)
    }

    private func refresh() {
        if expression.isEmpty { preview = ""; return }
        if let v = evaluate(), v.isFinite {
            let s = formatNumber(v, digits: digits)
            preview = s == expression ? "" : s
        }
    }
}
