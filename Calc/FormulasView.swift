import SwiftUI

private struct FormulaEntry: Identifiable {
    let id = UUID()
    let name: String
    let formula: String
    var note: String = ""
}

private struct FormulaGroup: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let items: [FormulaEntry]
}

private func f(_ name: String, _ formula: String, _ note: String = "") -> FormulaEntry {
    FormulaEntry(name: name, formula: formula, note: note)
}

private let formulaGroups: [FormulaGroup] = [
    FormulaGroup(title: "2D Shapes", icon: "square.on.circle", items: [
        f("Rectangle", "A = w × h\nP = 2(w + h)\nd = √(w² + h²)"),
        f("Square", "A = s²\nP = 4s\nd = s√2"),
        f("Triangle", "A = ½ b h", "base × height ÷ 2"),
        f("Heron's formula", "A = √(s(s − a)(s − b)(s − c))", "s = (a + b + c) / 2"),
        f("Equilateral triangle", "A = (√3 / 4) s²\nh = (√3 / 2) s"),
        f("Right triangle", "a² + b² = c²", "Pythagorean theorem"),
        f("Circle", "A = πr²\nC = 2πr = πd"),
        f("Sector", "A = ½ r² θ\ns = rθ", "θ in radians; s is the arc length"),
        f("Ellipse", "A = πab", "a, b are the semi-axes"),
        f("Trapezoid", "A = ½ (a + b) h", "a, b are the parallel sides"),
        f("Parallelogram", "A = b h"),
        f("Rhombus", "A = ½ d₁ d₂"),
        f("Annulus (ring)", "A = π(R² − r²)"),
        f("Regular polygon", "A = ½ n s a\nInterior angle = (n − 2) × 180° / n", "n sides of length s, apothem a"),
    ]),
    FormulaGroup(title: "3D Shapes", icon: "cube", items: [
        f("Cube", "V = s³\nSA = 6s²\nd = s√3"),
        f("Rectangular prism", "V = l w h\nSA = 2(lw + lh + wh)\nd = √(l² + w² + h²)"),
        f("Sphere", "V = (4/3) π r³\nSA = 4π r²"),
        f("Cylinder", "V = π r² h\nSA = 2π r (r + h)"),
        f("Cone", "V = ⅓ π r² h\nSA = π r (r + l)", "slant height l = √(r² + h²)"),
        f("Pyramid", "V = ⅓ B h", "B = base area"),
        f("Torus", "V = 2π² R r²\nSA = 4π² R r", "R = distance to the tube centre, r = tube radius"),
        f("Ellipsoid", "V = (4/3) π a b c"),
        f("Spherical cap", "V = π h² (3r − h) / 3\nA = 2π r h", "cap height h"),
        f("Euler's polyhedron formula", "V − E + F = 2"),
    ]),
    FormulaGroup(title: "Coordinate Geometry", icon: "point.topleft.down.to.point.bottomright.curvepath", items: [
        f("Distance", "d = √((x₂ − x₁)² + (y₂ − y₁)²)"),
        f("Midpoint", "M = ((x₁ + x₂)/2, (y₁ + y₂)/2)"),
        f("Slope", "m = (y₂ − y₁) / (x₂ − x₁)"),
        f("Line", "y = mx + b\ny − y₁ = m(x − x₁)", "slope-intercept and point-slope"),
        f("Perpendicular slope", "m₂ = −1 / m₁"),
        f("Circle", "(x − h)² + (y − k)² = r²"),
        f("Ellipse", "x²/a² + y²/b² = 1"),
        f("Hyperbola", "x²/a² − y²/b² = 1"),
        f("Parabola", "y = a(x − h)² + k"),
        f("Point to line distance", "d = |Ax₀ + By₀ + C| / √(A² + B²)"),
    ]),
    FormulaGroup(title: "Algebra", icon: "x.squareroot", items: [
        f("Quadratic formula", "x = (−b ± √(b² − 4ac)) / 2a", "solves ax² + bx + c = 0; Δ = b² − 4ac"),
        f("Vertex of a parabola", "h = −b / 2a\nk = c − b² / 4a"),
        f("Difference of squares", "a² − b² = (a − b)(a + b)"),
        f("Perfect squares", "(a ± b)² = a² ± 2ab + b²"),
        f("Sum / difference of cubes", "a³ ± b³ = (a ± b)(a² ∓ ab + b²)"),
        f("Binomial theorem", "(a + b)ⁿ = Σ C(n, k) aⁿ⁻ᵏ bᵏ"),
        f("Exponent rules", "aᵐ · aⁿ = aᵐ⁺ⁿ\n(aᵐ)ⁿ = aᵐⁿ\na⁻ⁿ = 1 / aⁿ\na^(m/n) = ⁿ√(aᵐ)"),
        f("Logarithm rules", "log(xy) = log x + log y\nlog(x/y) = log x − log y\nlog xⁿ = n log x\nlog_b x = ln x / ln b"),
        f("Arithmetic sequence", "aₙ = a₁ + (n − 1)d\nSₙ = n(a₁ + aₙ) / 2"),
        f("Geometric sequence", "aₙ = a₁ rⁿ⁻¹\nSₙ = a₁ (1 − rⁿ) / (1 − r)\nS∞ = a₁ / (1 − r)", "infinite sum needs |r| < 1"),
        f("Sums of powers", "Σk = n(n + 1) / 2\nΣk² = n(n + 1)(2n + 1) / 6\nΣk³ = [n(n + 1) / 2]²"),
        f("Permutations & combinations", "P(n, r) = n! / (n − r)!\nC(n, r) = n! / (r!(n − r)!)"),
        f("Complex numbers", "i² = −1\n|a + bi| = √(a² + b²)\neⁱᶿ = cos θ + i sin θ", "Euler's formula"),
        f("De Moivre's theorem", "(r eⁱᶿ)ⁿ = rⁿ eⁱⁿᶿ"),
    ]),
    FormulaGroup(title: "Trigonometry", icon: "angle", items: [
        f("Right-triangle ratios", "sin θ = opposite / hypotenuse\ncos θ = adjacent / hypotenuse\ntan θ = opposite / adjacent", "SOH CAH TOA"),
        f("Pythagorean identities", "sin²θ + cos²θ = 1\n1 + tan²θ = sec²θ\n1 + cot²θ = csc²θ"),
        f("Double angle", "sin 2θ = 2 sin θ cos θ\ncos 2θ = cos²θ − sin²θ = 2cos²θ − 1\ntan 2θ = 2 tan θ / (1 − tan²θ)"),
        f("Half angle", "sin²(θ/2) = (1 − cos θ) / 2\ncos²(θ/2) = (1 + cos θ) / 2"),
        f("Angle sum / difference", "sin(a ± b) = sin a cos b ± cos a sin b\ncos(a ± b) = cos a cos b ∓ sin a sin b\ntan(a ± b) = (tan a ± tan b) / (1 ∓ tan a tan b)"),
        f("Product to sum", "sin a cos b = ½ [sin(a + b) + sin(a − b)]\ncos a cos b = ½ [cos(a − b) + cos(a + b)]"),
        f("Law of sines", "a / sin A = b / sin B = c / sin C = 2R"),
        f("Law of cosines", "c² = a² + b² − 2ab cos C"),
        f("Triangle area (SAS)", "A = ½ a b sin C"),
        f("Degrees ↔ radians", "rad = deg × π / 180\ndeg = rad × 180 / π"),
        f("Common values", "sin 30° = ½   cos 30° = √3/2\nsin 45° = √2/2   cos 60° = ½\ntan 45° = 1"),
    ]),
    FormulaGroup(title: "Calculus", icon: "function", items: [
        f("Derivative rules", "(xⁿ)′ = n xⁿ⁻¹\n(fg)′ = f′g + fg′\n(f/g)′ = (f′g − fg′) / g²\n(f(g(x)))′ = f′(g(x)) · g′(x)", "power, product, quotient, chain"),
        f("Common derivatives", "(eˣ)′ = eˣ   (aˣ)′ = aˣ ln a\n(ln x)′ = 1/x\n(sin x)′ = cos x   (cos x)′ = −sin x\n(tan x)′ = sec²x\n(arcsin x)′ = 1/√(1 − x²)\n(arctan x)′ = 1/(1 + x²)"),
        f("Common integrals", "∫xⁿ dx = xⁿ⁺¹ / (n + 1) + C   (n ≠ −1)\n∫1/x dx = ln|x| + C\n∫eˣ dx = eˣ + C\n∫sin x dx = −cos x + C\n∫cos x dx = sin x + C\n∫sec²x dx = tan x + C"),
        f("Integration by parts", "∫u dv = uv − ∫v du"),
        f("Fundamental theorem", "∫ₐᵇ f(x) dx = F(b) − F(a)"),
        f("L'Hôpital's rule", "lim f/g = lim f′/g′", "for 0/0 or ∞/∞"),
        f("Taylor series", "f(x) = Σ f⁽ⁿ⁾(a) (x − a)ⁿ / n!"),
        f("Common series", "eˣ = Σ xⁿ / n!\nsin x = x − x³/3! + x⁵/5! − …\ncos x = 1 − x²/2! + x⁴/4! − …\n1/(1 − x) = Σ xⁿ   (|x| < 1)\nln(1 + x) = x − x²/2 + x³/3 − …"),
        f("Arc length", "L = ∫ₐᵇ √(1 + f′(x)²) dx"),
        f("Volume of revolution", "V = π ∫ₐᵇ f(x)² dx", "disk method"),
        f("Mean value theorem", "f′(c) = (f(b) − f(a)) / (b − a)"),
    ]),
    FormulaGroup(title: "Statistics & Probability", icon: "chart.bar", items: [
        f("Mean", "x̄ = Σxᵢ / n"),
        f("Variance & standard deviation", "σ² = Σ(xᵢ − μ)² / N\ns² = Σ(xᵢ − x̄)² / (n − 1)\nσ = √σ²", "population and sample"),
        f("z-score", "z = (x − μ) / σ"),
        f("Normal distribution", "f(x) = (1 / (σ√(2π))) e^(−(x − μ)² / 2σ²)"),
        f("Standard error", "SE = σ / √n"),
        f("Confidence interval", "x̄ ± z · σ / √n"),
        f("Union & conditional", "P(A ∪ B) = P(A) + P(B) − P(A ∩ B)\nP(A | B) = P(A ∩ B) / P(B)"),
        f("Bayes' theorem", "P(A | B) = P(B | A) P(A) / P(B)"),
        f("Binomial distribution", "P(X = k) = C(n, k) pᵏ (1 − p)ⁿ⁻ᵏ\nmean = np   variance = np(1 − p)"),
        f("Correlation", "r = Σ(x − x̄)(y − ȳ) / √(Σ(x − x̄)² Σ(y − ȳ)²)"),
        f("Linear regression", "y = a + bx\nb = r · (s_y / s_x)\na = ȳ − b x̄"),
        f("Expected value", "E[X] = Σ xᵢ P(xᵢ)"),
    ]),
    FormulaGroup(title: "Mechanics", icon: "gyroscope", items: [
        f("Velocity & acceleration", "v = Δx / Δt\na = Δv / Δt"),
        f("Kinematics (constant a)", "v = v₀ + at\nx = x₀ + v₀t + ½at²\nv² = v₀² + 2aΔx"),
        f("Newton's second law", "F = ma\nW = mg", "g ≈ 9.81 m/s²"),
        f("Momentum & impulse", "p = mv\nJ = FΔt = Δp"),
        f("Work, energy, power", "W = F d cos θ\nKE = ½mv²\nPE = mgh\nP = W / t"),
        f("Hooke's law", "F = −kx\nE = ½kx²"),
        f("Friction", "f = μN"),
        f("Circular motion", "a = v² / r\nF = mv² / r\nω = 2π / T"),
        f("Universal gravitation", "F = G m₁m₂ / r²", "G = 6.674 × 10⁻¹¹ N·m²/kg²"),
        f("Projectile motion", "Range R = v₀² sin 2θ / g\nMax height H = v₀² sin²θ / 2g"),
        f("Pendulum & spring periods", "T = 2π√(L / g)\nT = 2π√(m / k)"),
        f("Rotation", "τ = r F sin θ\nI = Σ m r²\nKE = ½Iω²"),
        f("Density & pressure", "ρ = m / V\nP = F / A\nP = ρ g h"),
        f("Escape velocity", "v = √(2GM / r)"),
    ]),
    FormulaGroup(title: "Waves, Electricity & Heat", icon: "bolt", items: [
        f("Wave speed", "v = f λ\nf = 1 / T"),
        f("Doppler effect", "f′ = f (v ± vₒ) / (v ∓ vₛ)"),
        f("Ohm's law", "V = I R"),
        f("Electric power", "P = I V = I² R = V² / R"),
        f("Resistors", "Series: R = R₁ + R₂\nParallel: 1/R = 1/R₁ + 1/R₂"),
        f("Coulomb's law", "F = k q₁q₂ / r²", "k ≈ 8.99 × 10⁹ N·m²/C²"),
        f("Capacitors", "C = Q / V\nE = ½ C V²"),
        f("Snell's law", "n₁ sin θ₁ = n₂ sin θ₂"),
        f("Thin lens", "1/f = 1/dₒ + 1/dᵢ"),
        f("Ideal gas law", "PV = nRT", "R = 8.314 J/(mol·K)"),
        f("Heat", "Q = m c ΔT"),
        f("Mass–energy", "E = mc²", "c = 299 792 458 m/s"),
        f("Photon energy", "E = hf = hc / λ", "h = 6.626 × 10⁻³⁴ J·s"),
        f("Temperature", "K = °C + 273.15\n°F = °C × 9/5 + 32"),
    ]),
    FormulaGroup(title: "Chemistry", icon: "flask", items: [
        f("Moles", "n = m / M"),
        f("Molarity", "M = n / V"),
        f("Dilution", "M₁V₁ = M₂V₂"),
        f("pH", "pH = −log[H⁺]\npH + pOH = 14"),
        f("Gas laws", "Boyle: P₁V₁ = P₂V₂\nCharles: V₁/T₁ = V₂/T₂\nCombined: P₁V₁/T₁ = P₂V₂/T₂"),
        f("Percent yield", "% yield = actual / theoretical × 100"),
        f("Avogadro's number", "N_A = 6.022 × 10²³ mol⁻¹"),
    ]),
    FormulaGroup(title: "Finance", icon: "dollarsign.circle", items: [
        f("Simple interest", "I = P r t"),
        f("Compound interest", "A = P (1 + r/n)^(nt)\nA = P e^(rt)", "second form is continuous compounding"),
        f("Loan payment", "M = P · r(1 + r)ⁿ / ((1 + r)ⁿ − 1)", "r = rate per period, n = number of payments"),
        f("Annuity future value", "FV = P ((1 + r)ⁿ − 1) / r"),
        f("Present value", "PV = FV / (1 + r)ⁿ"),
        f("Rule of 72", "years to double ≈ 72 / rate%"),
        f("Percent change", "(new − old) / old × 100%"),
    ]),
    FormulaGroup(title: "Constants", icon: "number", items: [
        f("π", "3.14159265358979"),
        f("e", "2.71828182845905"),
        f("Golden ratio φ", "(1 + √5) / 2 ≈ 1.61803398875"),
        f("√2, √3", "1.41421356237   1.73205080757"),
        f("Euler–Mascheroni γ", "0.57721566490153"),
        f("Speed of light", "c = 299 792 458 m/s"),
        f("Gravitational constant", "G = 6.674 × 10⁻¹¹ N·m²/kg²"),
        f("Planck constant", "h = 6.626 × 10⁻³⁴ J·s"),
        f("Boltzmann constant", "k = 1.381 × 10⁻²³ J/K"),
        f("Gas constant", "R = 8.314 J/(mol·K)"),
        f("Elementary charge", "e = 1.602 × 10⁻¹⁹ C"),
        f("Standard gravity", "g = 9.80665 m/s²"),
    ]),
]

struct FormulasView: View {
    @Environment(\.appAccent) private var accent

    @State private var query = ""
    @State private var selected: String?

    private var visibleGroups: [FormulaGroup] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return formulaGroups.compactMap { group in
            if let selected, group.title != selected { return nil }
            let items = q.isEmpty ? group.items : group.items.filter {
                $0.name.lowercased().contains(q) || $0.formula.lowercased().contains(q)
                    || $0.note.lowercased().contains(q) || group.title.lowercased().contains(q)
            }
            return items.isEmpty ? nil : FormulaGroup(title: group.title, icon: group.icon, items: items)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            searchField
            categoryChips
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(visibleGroups) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Label(group.title, systemImage: group.icon)
                                .font(.headline)
                                .padding(.leading, 4)
                            ForEach(group.items) { item in card(item) }
                        }
                    }
                    if visibleGroups.isEmpty {
                        Text("No formulas match “\(query)”.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    }
                }
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search formulas", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: Capsule())
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    chip("All", isSelected: selected == nil) { selected = nil }
                    ForEach(formulaGroups) { group in
                        chip(group.title, isSelected: selected == group.title) { selected = group.title }
                    }
                }
            }
        }
    }

    private func chip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
        }
        .buttonStyle(.plain)
        .glassEffect(isSelected ? .regular.tint(accent).interactive() : .regular.interactive(), in: Capsule())
    }

    private func card(_ item: FormulaEntry) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(item.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(item.formula)
                .font(.system(.body, design: .rounded).weight(.medium))
            if !item.note.isEmpty {
                Text(item.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .contextMenu {
            Button("Copy Formula", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = item.formula
            }
        }
    }
}
