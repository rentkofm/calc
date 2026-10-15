import SwiftUI

/// Palette of advanced functions. The calculator stays usable behind it at the medium detent.
struct AdvancedMathSheet: View {
    let model: CalculatorModel

    @Environment(\.dismiss) private var dismiss
    @AppStorage("haptics") private var haptics = true

    private struct Entry: Identifiable {
        let id = UUID()
        let token: String    // appended to the expression by "Insert"
        let syntax: String
        let example: String  // replaces the expression by "Try"
        let result: String
    }

    private struct Group_: Identifiable {
        let id = UUID()
        let title: String
        let entries: [Entry]
    }

    private static let groups: [Group_] = [
        Group_(title: "Calculus", entries: [
            Entry(token: "sum(", syntax: "Σ  sum(expr, k, from, to)", example: "sum(k^2,k,1,10)", result: "385"),
            Entry(token: "sum(", syntax: "Σ  to ∞ (converging)", example: "sum(1/k^2,k,1,inf)", result: "1.644934 (π²/6)"),
            Entry(token: "prod(", syntax: "Π  prod(expr, k, from, to)", example: "prod(k,k,1,5)", result: "120"),
            Entry(token: "int(", syntax: "∫  int(expr, x, from, to)", example: "int(sin(x),x,0,pi)", result: "2"),
            Entry(token: "int(", syntax: "∫  infinite bounds", example: "int(exp(-x^2),x,-inf,inf)", result: "1.772454 (√π)"),
            Entry(token: "diff(", syntax: "d/dx  diff(expr, x, at)", example: "diff(x^3,x,2)", result: "12"),
            Entry(token: "lim(", syntax: "lim  lim(expr, x, approaches)", example: "lim(sin(x)/x,x,0)", result: "1"),
        ]),
        Group_(title: "Combinatorics & Number Theory", entries: [
            Entry(token: "nCr(", syntax: "nCr(n, r)  combinations", example: "nCr(10,3)", result: "120"),
            Entry(token: "nPr(", syntax: "nPr(n, r)  permutations", example: "nPr(10,3)", result: "720"),
            Entry(token: "fib(", syntax: "fib(n)  Fibonacci", example: "fib(10)", result: "55"),
            Entry(token: "gcd(", syntax: "gcd(a, b)", example: "gcd(84,36)", result: "12"),
            Entry(token: "lcm(", syntax: "lcm(a, b)", example: "lcm(4,6)", result: "12"),
            Entry(token: "mod(", syntax: "mod(a, b)  remainder", example: "mod(-7,3)", result: "2"),
        ]),
        Group_(title: "Statistics", entries: [
            Entry(token: "min(", syntax: "min(a, b, …)", example: "min(4,2,9)", result: "2"),
            Entry(token: "max(", syntax: "max(a, b, …)", example: "max(4,2,9)", result: "9"),
            Entry(token: "avg(", syntax: "avg(a, b, …)  mean", example: "avg(2,4,9)", result: "5"),
            Entry(token: "rand(", syntax: "rand()  or  rand(a, b)", example: "rand(1,6)", result: "random"),
        ]),
        Group_(title: "Special Functions", entries: [
            Entry(token: "gamma(", syntax: "gamma(x)  Γ", example: "gamma(5)", result: "24"),
            Entry(token: "erf(", syntax: "erf(x)  error function", example: "erf(1)", result: "0.842701"),
            Entry(token: "atan2(", syntax: "atan2(y, x)", example: "atan2(1,1)", result: "45 (DEG) / 0.785398 (RAD)"),
            Entry(token: "hypot(", syntax: "hypot(a, b)", example: "hypot(3,4)", result: "5"),
            Entry(token: "root(", syntax: "root(x, n)  nth root", example: "root(27,3)", result: "3"),
            Entry(token: "logb(", syntax: "logb(x, base)", example: "logb(8,2)", result: "3"),
            Entry(token: "exp10(", syntax: "exp10(x)  10ˣ", example: "exp10(3)", result: "1000"),
            Entry(token: "sign(", syntax: "sign(x)", example: "sign(-5)", result: "-1"),
        ]),
        Group_(title: "More Trig", entries: [
            Entry(token: "sec(", syntax: "sec(x)", example: "sec(60)", result: "2 (DEG)"),
            Entry(token: "csc(", syntax: "csc(x)", example: "csc(30)", result: "2 (DEG)"),
            Entry(token: "cot(", syntax: "cot(x)", example: "cot(45)", result: "1 (DEG)"),
            Entry(token: "asinh(", syntax: "asinh(x)  acosh  atanh", example: "asinh(1)", result: "0.881374"),
            Entry(token: "deg(", syntax: "deg(x)  radians → degrees", example: "deg(pi)", result: "180"),
            Entry(token: "rad(", syntax: "rad(x)  degrees → radians", example: "rad(180)", result: "3.141593"),
        ]),
    ]

    private static let quickKeys = [",", "k", "n", "x", "∞", "φ", "τ", "(", ")"]

    var body: some View {
        NavigationStack {
            List {
                Section("Quick keys") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Self.quickKeys, id: \.self) { key in
                                Button {
                                    insert(key)
                                } label: {
                                    Text(key)
                                        .font(.system(size: 18, weight: .medium, design: .rounded))
                                        .frame(minWidth: 36, minHeight: 34)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                ForEach(Self.groups) { group in
                    Section(group.title) {
                        ForEach(group.entries) { entry in row(entry) }
                    }
                }
            }
            .navigationTitle("Advanced Math")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
    }

    private func row(_ entry: Entry) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.syntax)
                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                Text("\(entry.example) = \(entry.result)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Button("Insert") { insert(entry.token) }
                .buttonStyle(.bordered)
            Button("Try") {
                if haptics { Haptics.tap() }
                model.replace(with: entry.example)
            }
            .buttonStyle(.borderedProminent)
        }
        .controlSize(.small)
    }

    private func insert(_ s: String) {
        if haptics { Haptics.tap() }
        model.input(s)
    }
}
