import Foundation

enum RegressionModel: String, Codable, CaseIterable, Identifiable {
    case none, linear, quadratic, cubic, exponential, power, logarithmic
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "No Fit"
        case .linear: return "Linear"
        case .quadratic: return "Quadratic"
        case .cubic: return "Cubic"
        case .exponential: return "Exponential"
        case .power: return "Power"
        case .logarithmic: return "Logarithmic"
        }
    }
}

struct RegressionResult {
    var model: RegressionModel
    var coefficients: [Double]
    var r2: Double
    var equation: String
    var f: (Double) -> Double
}

enum Regression {
    static func fit(_ model: RegressionModel, xs: [Double], ys: [Double]) -> RegressionResult? {
        guard xs.count == ys.count, xs.count >= 2 else { return nil }
        var c: [Double]
        var f: (Double) -> Double

        switch model {
        case .none:
            return nil
        case .linear, .quadratic, .cubic:
            let degree = model == .linear ? 1 : model == .quadratic ? 2 : 3
            guard xs.count > degree, let p = polyFit(xs, ys, degree: degree) else { return nil }
            c = p
            f = { x in p.enumerated().reduce(0) { $0 + $1.element * pow(x, Double($1.offset)) } }
        case .exponential:
            guard ys.allSatisfy({ $0 > 0 }), let p = polyFit(xs, ys.map(log), degree: 1) else { return nil }
            let (a, b) = (exp(p[0]), p[1])
            c = [a, b]
            f = { a * exp(b * $0) }
        case .power:
            guard xs.allSatisfy({ $0 > 0 }), ys.allSatisfy({ $0 > 0 }),
                  let p = polyFit(xs.map(log), ys.map(log), degree: 1) else { return nil }
            let (a, b) = (exp(p[0]), p[1])
            c = [a, b]
            f = { a * pow($0, b) }
        case .logarithmic:
            guard xs.allSatisfy({ $0 > 0 }), let p = polyFit(xs.map(log), ys, degree: 1) else { return nil }
            let (a, b) = (p[0], p[1])
            c = [a, b]
            f = { a + b * log($0) }
        }

        let mean = Stats.mean(ys)
        let total = ys.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
        let residual = zip(xs, ys).reduce(0) { $0 + ($1.1 - f($1.0)) * ($1.1 - f($1.0)) }
        let r2 = total == 0 ? 1 : 1 - residual / total
        return RegressionResult(model: model, coefficients: c, r2: r2, equation: equation(model, c), f: f)
    }

    /// Least-squares polynomial coefficients, lowest power first.
    static func polyFit(_ xs: [Double], _ ys: [Double], degree: Int) -> [Double]? {
        let n = degree + 1
        var a = [[Double]](repeating: [Double](repeating: 0, count: n + 1), count: n)
        for (x, y) in zip(xs, ys) {
            var powers = [Double](repeating: 1, count: 2 * n)
            for k in 1..<(2 * n) { powers[k] = powers[k - 1] * x }
            for r in 0..<n {
                for col in 0..<n { a[r][col] += powers[r + col] }
                a[r][n] += powers[r] * y
            }
        }
        // Gaussian elimination with partial pivoting.
        for col in 0..<n {
            var pivot = col
            for r in col..<n where abs(a[r][col]) > abs(a[pivot][col]) { pivot = r }
            guard abs(a[pivot][col]) > 1e-12 else { return nil }
            a.swapAt(col, pivot)
            for r in 0..<n where r != col {
                let factor = a[r][col] / a[col][col]
                if factor == 0 { continue }
                for k in col...n { a[r][k] -= factor * a[col][k] }
            }
        }
        return (0..<n).map { a[$0][n] / a[$0][$0] }
    }

    private static func num(_ v: Double) -> String { formatNumber(v, digits: 5) }

    private static func signed(_ v: Double) -> String {
        v < 0 ? "− \(num(-v))" : "+ \(num(v))"
    }

    static func equation(_ model: RegressionModel, _ c: [Double]) -> String {
        switch model {
        case .none: return ""
        case .linear: return "y = \(num(c[1]))x \(signed(c[0]))"
        case .quadratic: return "y = \(num(c[2]))x² \(signed(c[1]))x \(signed(c[0]))"
        case .cubic: return "y = \(num(c[3]))x³ \(signed(c[2]))x² \(signed(c[1]))x \(signed(c[0]))"
        case .exponential: return "y = \(num(c[0]))·e^(\(num(c[1]))x)"
        case .power: return "y = \(num(c[0]))·x^\(num(c[1]))"
        case .logarithmic: return "y = \(num(c[0])) \(signed(c[1]))·ln x"
        }
    }

    /// Text for the expression field that plots the fit.
    static func expression(_ r: RegressionResult) -> String {
        let c = r.coefficients.map { String(format: "%.12g", $0) }
        switch r.model {
        case .none: return ""
        case .linear: return "(\(c[1]))x+(\(c[0]))"
        case .quadratic: return "(\(c[2]))x^2+(\(c[1]))x+(\(c[0]))"
        case .cubic: return "(\(c[3]))x^3+(\(c[2]))x^2+(\(c[1]))x+(\(c[0]))"
        case .exponential: return "(\(c[0]))exp((\(c[1]))x)"
        case .power: return "(\(c[0]))x^(\(c[1]))"
        case .logarithmic: return "(\(c[0]))+(\(c[1]))ln(x)"
        }
    }

    /// Pairs from lines such as "1, 2" / "1 2" / "1;2" / "1\t2".
    static func parsePairs(_ text: String) -> (xs: [Double], ys: [Double]) {
        var xs: [Double] = [], ys: [Double] = []
        for line in text.split(whereSeparator: \.isNewline) {
            let parts = line.split(whereSeparator: { ",; \t".contains($0) }).compactMap { Double($0) }
            if parts.count >= 2 { xs.append(parts[0]); ys.append(parts[1]) }
        }
        return (xs, ys)
    }

    static func parseList(_ text: String) -> [Double] {
        text.split(whereSeparator: { ",; \t\n\r".contains($0) }).compactMap { Double($0) }
    }
}

enum Stats {
    static func mean(_ v: [Double]) -> Double { v.isEmpty ? .nan : v.reduce(0, +) / Double(v.count) }

    static func median(_ v: [Double]) -> Double { quantile(v.sorted(), 0.5) }

    /// Linear-interpolated quantile (type 7) of already-sorted data.
    static func quantile(_ s: [Double], _ p: Double) -> Double {
        guard !s.isEmpty else { return .nan }
        let h = Double(s.count - 1) * p
        let lo = Int(floor(h)), hi = Int(ceil(h))
        return s[lo] + (s[hi] - s[lo]) * (h - Double(lo))
    }

    static func variance(_ v: [Double], sample: Bool) -> Double {
        let n = Double(v.count)
        guard n > (sample ? 1 : 0) else { return .nan }
        let m = mean(v)
        return v.reduce(0) { $0 + ($1 - m) * ($1 - m) } / (sample ? n - 1 : n)
    }

    static func sd(_ v: [Double], sample: Bool) -> Double { variance(v, sample: sample).squareRoot() }

    static func skewness(_ v: [Double]) -> Double {
        let n = Double(v.count), m = mean(v), s = sd(v, sample: false)
        guard n > 2, s > 0 else { return .nan }
        return v.reduce(0) { $0 + pow(($1 - m) / s, 3) } / n
    }

    static func excessKurtosis(_ v: [Double]) -> Double {
        let n = Double(v.count), m = mean(v), s = sd(v, sample: false)
        guard n > 3, s > 0 else { return .nan }
        return v.reduce(0) { $0 + pow(($1 - m) / s, 4) } / n - 3
    }

    static func modes(_ v: [Double]) -> [Double] {
        var counts: [Double: Int] = [:]
        for x in v { counts[x, default: 0] += 1 }
        guard let top = counts.values.max(), top > 1 else { return [] }
        return counts.filter { $0.value == top }.keys.sorted()
    }

    static func correlation(_ xs: [Double], _ ys: [Double]) -> Double {
        let mx = mean(xs), my = mean(ys)
        var sxy = 0.0, sxx = 0.0, syy = 0.0
        for (x, y) in zip(xs, ys) {
            sxy += (x - mx) * (y - my)
            sxx += (x - mx) * (x - mx)
            syy += (y - my) * (y - my)
        }
        return sxy / (sxx * syy).squareRoot()
    }

    // MARK: Distributions

    static func normalPDF(_ x: Double, mean m: Double, sd s: Double) -> Double {
        exp(-0.5 * pow((x - m) / s, 2)) / (s * (2 * Double.pi).squareRoot())
    }

    static func normalCDF(_ x: Double, mean m: Double = 0, sd s: Double = 1) -> Double {
        0.5 * erfc(-(x - m) / (s * 2.0.squareRoot()))
    }

    /// Inverse of the standard normal CDF (Acklam's approximation plus one Halley step).
    static func normalInverse(_ p: Double) -> Double {
        guard p > 0, p < 1 else { return p <= 0 ? -.infinity : .infinity }
        let a = [-3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02,
                 1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00]
        let b = [-5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02,
                 6.680131188771972e+01, -1.328068155288572e+01]
        let c = [-7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00,
                 -2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00]
        let d = [7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00, 3.754408661907416e+00]
        var x: Double
        if p < 0.02425 {
            let q = (-2 * log(p)).squareRoot()
            x = (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5])
                / ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1)
        } else if p > 1 - 0.02425 {
            let q = (-2 * log(1 - p)).squareRoot()
            x = -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5])
                / ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1)
        } else {
            let q = p - 0.5, r = q * q
            x = (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q
                / (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1)
        }
        let e = normalCDF(x) - p
        let u = e * (2 * Double.pi).squareRoot() * exp(x * x / 2)
        return x - u / (1 + x * u / 2)
    }

    /// Student's t quantile (exact for 1–2 degrees of freedom, Cornish–Fisher otherwise).
    static func tQuantile(_ p: Double, df: Double) -> Double {
        if df <= 1 { return tan(Double.pi * (p - 0.5)) }
        if df <= 2 { return (2 * p - 1) / (2 * p * (1 - p)).squareRoot() }
        let z = normalInverse(p), v = df
        let z3 = pow(z, 3), z5 = pow(z, 5), z7 = pow(z, 7)
        return z + (z3 + z) / (4 * v)
            + (5 * z5 + 16 * z3 + 3 * z) / (96 * v * v)
            + (3 * z7 + 19 * z5 + 17 * z3 - 15 * z) / (384 * v * v * v)
    }

    static func binomialPMF(n: Int, k: Int, p: Double) -> Double {
        guard k >= 0, k <= n else { return 0 }
        if p <= 0 { return k == 0 ? 1 : 0 }
        if p >= 1 { return k == n ? 1 : 0 }
        let logC = lgamma(Double(n) + 1) - lgamma(Double(k) + 1) - lgamma(Double(n - k) + 1)
        return exp(logC + Double(k) * log(p) + Double(n - k) * log(1 - p))
    }

    static func binomialCDF(n: Int, k: Int, p: Double) -> Double {
        guard k >= 0 else { return 0 }
        return min(1, (0...min(k, n)).reduce(0) { $0 + binomialPMF(n: n, k: $1, p: p) })
    }

    static func poissonPMF(k: Int, lambda: Double) -> Double {
        guard k >= 0, lambda > 0 else { return k == 0 ? 1 : 0 }
        return exp(Double(k) * log(lambda) - lambda - lgamma(Double(k) + 1))
    }

    static func poissonCDF(k: Int, lambda: Double) -> Double {
        guard k >= 0 else { return 0 }
        return min(1, (0...k).reduce(0) { $0 + poissonPMF(k: $1, lambda: lambda) })
    }
}
