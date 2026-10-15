import SwiftUI

/// Descriptive statistics, regression, distributions and confidence intervals.
struct StatsView: View {
    enum Tool: String, CaseIterable, Identifiable {
        case describe = "Describe", regression = "Regression", distributions = "Distributions", intervals = "Intervals"
        var id: String { rawValue }
    }

    @State private var tool: Tool = .describe

    var body: some View {
        VStack(spacing: 0) {
            Picker("Tool", selection: $tool) {
                ForEach(Tool.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            ZStack {
                DescribeTool().visible(tool == .describe)
                RegressionTool().visible(tool == .regression)
                DistributionTool().visible(tool == .distributions)
                IntervalTool().visible(tool == .intervals)
            }
        }
    }
}

private func value(_ s: String) -> Double? {
    Double(s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "−", with: "-"))
}

private func fmt(_ v: Double) -> String { v.isFinite ? formatNumber(v, digits: 8) : "—" }

private struct NumberField: View {
    let label: String
    @Binding var text: String

    var body: some View {
        LabeledContent(label) {
            TextField("0", text: $text)
                .multilineTextAlignment(.trailing)
                .keyboardType(.numbersAndPunctuation)
                .monospacedDigit()
        }
    }
}

private struct ResultRow: View {
    let label: String
    let result: String

    init(_ label: String, _ result: String) { self.label = label; self.result = result }
    init(_ label: String, _ v: Double) { self.label = label; self.result = fmt(v) }

    var body: some View {
        LabeledContent(label) { Text(result).monospacedDigit().textSelection(.enabled) }
    }
}

private struct DataEditor: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        TextEditor(text: $text)
            .font(.system(size: 16, design: .monospaced))
            .keyboardType(.numbersAndPunctuation)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 100)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8).padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
    }
}

// MARK: Describe

private struct DescribeTool: View {
    @State private var text = ""

    var body: some View {
        let data = Regression.parseList(text)
        let sorted = data.sorted()
        let q1 = Stats.quantile(sorted, 0.25), q3 = Stats.quantile(sorted, 0.75)
        let iqr = q3 - q1
        let outliers = sorted.filter { $0 < q1 - 1.5 * iqr || $0 > q3 + 1.5 * iqr }
        Form {
            Section("Data") {
                DataEditor(text: $text, placeholder: "Numbers separated by commas, spaces or lines")
            }
            if data.count >= 1 {
                Section("Summary") {
                    ResultRow("Count", Double(data.count))
                    ResultRow("Sum", data.reduce(0, +))
                    ResultRow("Mean", Stats.mean(data))
                    ResultRow("Median", Stats.median(data))
                    ResultRow("Mode", Stats.modes(data).isEmpty ? "none" : Stats.modes(data).map(fmt).joined(separator: ", "))
                    ResultRow("Minimum", sorted.first ?? .nan)
                    ResultRow("Maximum", sorted.last ?? .nan)
                    ResultRow("Range", (sorted.last ?? .nan) - (sorted.first ?? .nan))
                }
                Section("Spread") {
                    ResultRow("Q1", q1)
                    ResultRow("Q3", q3)
                    ResultRow("IQR", iqr)
                    ResultRow("Sample SD (s)", Stats.sd(data, sample: true))
                    ResultRow("Population SD (σ)", Stats.sd(data, sample: false))
                    ResultRow("Sample variance", Stats.variance(data, sample: true))
                    ResultRow("Population variance", Stats.variance(data, sample: false))
                    ResultRow("Standard error", Stats.sd(data, sample: true) / Double(data.count).squareRoot())
                }
                Section("Shape") {
                    ResultRow("Skewness", Stats.skewness(data))
                    ResultRow("Excess kurtosis", Stats.excessKurtosis(data))
                    ResultRow("Outliers", outliers.isEmpty ? "none" : outliers.map(fmt).joined(separator: ", "))
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}

// MARK: Regression

private struct RegressionTool: View {
    @State private var text = ""
    @State private var model: RegressionModel = .linear
    @State private var predictX = ""

    var body: some View {
        let (xs, ys) = Regression.parsePairs(text)
        let result = model == .none ? nil : Regression.fit(model, xs: xs, ys: ys)
        Form {
            Section("Data (x, y per line)") {
                DataEditor(text: $text, placeholder: "1, 2\n2, 4.1\n3, 5.9")
                Picker("Model", selection: $model) {
                    ForEach(RegressionModel.allCases.filter { $0 != .none }) { Text($0.label).tag($0) }
                }
            }
            if !xs.isEmpty {
                Section("Result") {
                    ResultRow("Points", Double(xs.count))
                    if let r = result {
                        ResultRow("Equation", r.equation)
                        ResultRow("R²", r.r2)
                        if model == .linear { ResultRow("Correlation (r)", Stats.correlation(xs, ys)) }
                        ForEach(Array(r.coefficients.enumerated()), id: \.offset) { i, c in
                            ResultRow(coefficientName(model, i), c)
                        }
                    } else {
                        Text(xs.count < 2 ? "Enter at least two points." : "This model can't fit that data.")
                            .foregroundStyle(.secondary)
                    }
                }
                if let r = result {
                    Section("Predict") {
                        NumberField(label: "x", text: $predictX)
                        if let x = value(predictX) { ResultRow("y", r.f(x)) }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func coefficientName(_ model: RegressionModel, _ i: Int) -> String {
        switch model {
        case .linear: return ["Intercept", "Slope"][i]
        case .quadratic, .cubic: return i == 0 ? "Constant" : "x^\(i) coefficient"
        case .exponential, .power: return i == 0 ? "a" : "b"
        case .logarithmic: return i == 0 ? "a" : "b"
        case .none: return ""
        }
    }
}

// MARK: Distributions

private struct DistributionTool: View {
    enum Kind: String, CaseIterable, Identifiable {
        case normal = "Normal", binomial = "Binomial", poisson = "Poisson"
        var id: String { rawValue }
    }
    enum NormalMode: String, CaseIterable, Identifiable {
        case below = "P(X ≤ x)", above = "P(X ≥ x)", between = "P(a ≤ X ≤ b)", inverse = "Inverse"
        var id: String { rawValue }
    }

    @State private var kind: Kind = .normal
    @State private var normalMode: NormalMode = .below
    @State private var mean = "0"
    @State private var sd = "1"
    @State private var x = "1"
    @State private var a = "-1"
    @State private var b = "1"
    @State private var p = "0.975"
    @State private var n = "10"
    @State private var prob = "0.5"
    @State private var k = "5"
    @State private var lambda = "3"
    @State private var kPoisson = "2"

    var body: some View {
        Form {
            Section {
                Picker("Distribution", selection: $kind) {
                    ForEach(Kind.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            switch kind {
            case .normal: normalSections
            case .binomial: binomialSections
            case .poisson: poissonSections
            }
        }
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder private var normalSections: some View {
        let m = value(mean) ?? 0, s = value(sd) ?? 1
        Section("Parameters") {
            NumberField(label: "Mean (μ)", text: $mean)
            NumberField(label: "Std deviation (σ)", text: $sd)
            Picker("Find", selection: $normalMode) {
                ForEach(NormalMode.allCases) { Text($0.rawValue).tag($0) }
            }
            switch normalMode {
            case .below, .above: NumberField(label: "x", text: $x)
            case .between:
                NumberField(label: "a", text: $a)
                NumberField(label: "b", text: $b)
            case .inverse: NumberField(label: "Probability", text: $p)
            }
        }
        Section("Result") {
            if s <= 0 {
                Text("σ must be positive.").foregroundStyle(.secondary)
            } else {
                switch normalMode {
                case .below:
                    if let v = value(x) { ResultRow("P(X ≤ x)", Stats.normalCDF(v, mean: m, sd: s)); ResultRow("z-score", (v - m) / s) }
                case .above:
                    if let v = value(x) { ResultRow("P(X ≥ x)", 1 - Stats.normalCDF(v, mean: m, sd: s)); ResultRow("z-score", (v - m) / s) }
                case .between:
                    if let lo = value(a), let hi = value(b) {
                        ResultRow("P(a ≤ X ≤ b)", Stats.normalCDF(hi, mean: m, sd: s) - Stats.normalCDF(lo, mean: m, sd: s))
                    }
                case .inverse:
                    if let q = value(p), q > 0, q < 1 {
                        ResultRow("x", m + s * Stats.normalInverse(q))
                        ResultRow("z", Stats.normalInverse(q))
                    }
                }
            }
        }
    }

    @ViewBuilder private var binomialSections: some View {
        Section("Parameters") {
            NumberField(label: "Trials (n)", text: $n)
            NumberField(label: "Probability (p)", text: $prob)
            NumberField(label: "Successes (k)", text: $k)
        }
        Section("Result") {
            if let nn = value(n).map({ Int($0) }), let pp = value(prob), let kk = value(k).map({ Int($0) }),
               nn >= 0, nn < 100_000, pp >= 0, pp <= 1 {
                ResultRow("P(X = k)", Stats.binomialPMF(n: nn, k: kk, p: pp))
                ResultRow("P(X ≤ k)", Stats.binomialCDF(n: nn, k: kk, p: pp))
                ResultRow("P(X ≥ k)", 1 - Stats.binomialCDF(n: nn, k: kk - 1, p: pp))
                ResultRow("Mean", Double(nn) * pp)
                ResultRow("Std deviation", (Double(nn) * pp * (1 - pp)).squareRoot())
            } else {
                Text("Enter n ≥ 0, 0 ≤ p ≤ 1 and k.").foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var poissonSections: some View {
        Section("Parameters") {
            NumberField(label: "Rate (λ)", text: $lambda)
            NumberField(label: "Events (k)", text: $kPoisson)
        }
        Section("Result") {
            if let l = value(lambda), l > 0, let kk = value(kPoisson).map({ Int($0) }), kk < 100_000 {
                ResultRow("P(X = k)", Stats.poissonPMF(k: kk, lambda: l))
                ResultRow("P(X ≤ k)", Stats.poissonCDF(k: kk, lambda: l))
                ResultRow("P(X ≥ k)", 1 - Stats.poissonCDF(k: kk - 1, lambda: l))
                ResultRow("Mean and variance", l)
            } else {
                Text("Enter λ > 0 and k.").foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: Intervals

private struct IntervalTool: View {
    enum Kind: String, CaseIterable, Identifiable {
        case mean = "Mean", proportion = "Proportion", zTest = "z-Test"
        var id: String { rawValue }
    }

    @State private var kind: Kind = .mean
    @State private var xbar = ""
    @State private var s = ""
    @State private var n = ""
    @State private var level = "95"
    @State private var successes = ""
    @State private var trials = ""
    @State private var mu0 = ""
    @State private var sigma = ""

    var body: some View {
        Form {
            Section {
                Picker("Procedure", selection: $kind) {
                    ForEach(Kind.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            switch kind {
            case .mean: meanSections
            case .proportion: proportionSections
            case .zTest: zSections
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var confidence: Double? {
        guard let l = value(level), l > 0, l < 100 else { return nil }
        return l / 100
    }

    @ViewBuilder private var meanSections: some View {
        Section("Sample") {
            NumberField(label: "Mean (x̄)", text: $xbar)
            NumberField(label: "Std deviation (s)", text: $s)
            NumberField(label: "Size (n)", text: $n)
            NumberField(label: "Confidence (%)", text: $level)
        }
        Section("Confidence interval (t)") {
            if let m = value(xbar), let sd = value(s), let nn = value(n), nn > 1, sd >= 0, let c = confidence {
                let t = Stats.tQuantile(1 - (1 - c) / 2, df: nn - 1)
                let margin = t * sd / nn.squareRoot()
                ResultRow("Interval", "\(fmt(m - margin)) to \(fmt(m + margin))")
                ResultRow("Margin of error", margin)
                ResultRow("Critical t", t)
            } else {
                Text("Fill in every field (n must be at least 2).").foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var proportionSections: some View {
        Section("Sample") {
            NumberField(label: "Successes", text: $successes)
            NumberField(label: "Trials (n)", text: $trials)
            NumberField(label: "Confidence (%)", text: $level)
        }
        Section("Wilson interval") {
            if let x = value(successes), let nn = value(trials), nn > 0, x >= 0, x <= nn, let c = confidence {
                let z = Stats.normalInverse(1 - (1 - c) / 2)
                let p = x / nn
                let denom = 1 + z * z / nn
                let centre = (p + z * z / (2 * nn)) / denom
                let margin = z * (p * (1 - p) / nn + z * z / (4 * nn * nn)).squareRoot() / denom
                ResultRow("Sample proportion", p)
                ResultRow("Interval", "\(fmt(max(0, centre - margin))) to \(fmt(min(1, centre + margin)))")
            } else {
                Text("Enter successes, trials and a confidence level.").foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var zSections: some View {
        Section("Sample") {
            NumberField(label: "Sample mean (x̄)", text: $xbar)
            NumberField(label: "Hypothesized mean (μ₀)", text: $mu0)
            NumberField(label: "Known σ", text: $sigma)
            NumberField(label: "Size (n)", text: $n)
        }
        Section("Result") {
            if let m = value(xbar), let m0 = value(mu0), let sd = value(sigma), sd > 0, let nn = value(n), nn > 0 {
                let z = (m - m0) / (sd / nn.squareRoot())
                ResultRow("z", z)
                ResultRow("p (two-tailed)", 2 * (1 - Stats.normalCDF(abs(z))))
                ResultRow("p (left-tailed)", Stats.normalCDF(z))
                ResultRow("p (right-tailed)", 1 - Stats.normalCDF(z))
            } else {
                Text("Fill in every field.").foregroundStyle(.secondary)
            }
        }
    }
}
