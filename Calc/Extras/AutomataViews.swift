import SwiftUI

/// Draws a grid of 0/1 cells as a crisp (non-interpolated) image.
private func gridImage(cols: Int, rows: Int, cells: [UInt8], on: (UInt8, UInt8, UInt8)) -> CGImage? {
    var rgba = [UInt8](repeating: 0, count: cols * rows * 4)
    for i in 0..<(cols * rows) where cells[i] != 0 {
        rgba[i * 4] = on.0; rgba[i * 4 + 1] = on.1; rgba[i * 4 + 2] = on.2; rgba[i * 4 + 3] = 255
    }
    return Raster.cgImage(width: cols, height: rows, rgba: rgba)
}

private func rgb(_ c: Color) -> (UInt8, UInt8, UInt8) {
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    UIColor(c).getRed(&r, green: &g, blue: &b, alpha: &a)
    return (UInt8(r * 255), UInt8(g * 255), UInt8(b * 255))
}

/// Drives a simulation at `rate` steps per second from a TimelineView.
private struct StepClock {
    var accumulator = 0.0
    var last: Date?

    /// Number of steps due at `date`.
    mutating func steps(at date: Date, rate: Double) -> Int {
        defer { last = date }
        guard let last else { return 0 }
        accumulator += min(date.timeIntervalSince(last), 0.1) * rate
        let n = Int(accumulator)
        accumulator -= Double(n)
        return min(n, 400)
    }
}

// MARK: - Conway's Game of Life

@Observable
private final class LifeEngine {
    private(set) var cols = 0
    private(set) var rows = 0
    private(set) var generation = 0
    private(set) var population = 0
    private(set) var image: CGImage?
    @ObservationIgnored private var cells: [UInt8] = []
    @ObservationIgnored private var next: [UInt8] = []

    func setup(cols: Int, rows: Int) {
        self.cols = max(8, cols); self.rows = max(8, rows)
        cells = [UInt8](repeating: 0, count: self.cols * self.rows)
        next = cells
        generation = 0
    }

    func step() {
        guard cols > 0 else { return }
        for y in 0..<rows {
            let up = ((y + rows - 1) % rows) * cols, mid = y * cols, dn = ((y + 1) % rows) * cols
            for x in 0..<cols {
                let l = x == 0 ? cols - 1 : x - 1, r = x == cols - 1 ? 0 : x + 1
                let n = Int(cells[up + l]) + Int(cells[up + x]) + Int(cells[up + r])
                    + Int(cells[mid + l]) + Int(cells[mid + r])
                    + Int(cells[dn + l]) + Int(cells[dn + x]) + Int(cells[dn + r])
                next[mid + x] = (n == 3 || (n == 2 && cells[mid + x] == 1)) ? 1 : 0
            }
        }
        swap(&cells, &next)
        generation += 1
    }

    func clear() {
        for i in cells.indices { cells[i] = 0 }
        generation = 0
    }

    func randomize(_ density: Double) {
        var rng = SplitMix64(state: UInt64(Date().timeIntervalSince1970 * 1000))
        for i in cells.indices { cells[i] = rng.nextDouble() < density ? 1 : 0 }
        generation = 0
    }

    /// Places a pattern (cell offsets) centred in the grid, after clearing it.
    func place(_ pattern: [(Int, Int)]) {
        clear()
        let w = (pattern.map { $0.0 }.max() ?? 0) + 1, h = (pattern.map { $0.1 }.max() ?? 0) + 1
        let ox = (cols - w) / 2, oy = (rows - h) / 2
        for (x, y) in pattern where ox + x >= 0 && oy + y >= 0 && ox + x < cols && oy + y < rows {
            cells[(oy + y) * cols + ox + x] = 1
        }
    }

    func cell(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < cols && y < rows && cells[y * cols + x] != 0 }

    func set(_ x: Int, _ y: Int, _ alive: Bool) {
        guard x >= 0, y >= 0, x < cols, y < rows else { return }
        cells[y * cols + x] = alive ? 1 : 0
    }

    func render(_ color: (UInt8, UInt8, UInt8)) {
        population = cells.reduce(0) { $0 + Int($1) }
        image = gridImage(cols: cols, rows: rows, cells: cells, on: color)
    }
}

struct LifeView: View {
    let active: Bool
    @Environment(\.appAccent) private var accent

    private struct Pattern: Identifiable {
        let name: String
        let cells: [(Int, Int)]
        var id: String { name }
    }

    private static let patterns: [Pattern] = [
        Pattern(name: "Glider", cells: [(1, 0), (2, 1), (0, 2), (1, 2), (2, 2)]),
        Pattern(name: "R-pentomino", cells: [(1, 0), (2, 0), (0, 1), (1, 1), (1, 2)]),
        Pattern(name: "Acorn", cells: [(1, 0), (3, 1), (0, 2), (1, 2), (4, 2), (5, 2), (6, 2)]),
        Pattern(name: "Gosper glider gun", cells: [(24, 0), (22, 1), (24, 1), (12, 2), (13, 2), (20, 2), (21, 2), (34, 2), (35, 2),
                               (11, 3), (15, 3), (20, 3), (21, 3), (34, 3), (35, 3), (0, 4), (1, 4), (10, 4),
                               (16, 4), (20, 4), (21, 4), (0, 5), (1, 5), (10, 5), (14, 5), (16, 5), (17, 5),
                               (22, 5), (24, 5), (10, 6), (16, 6), (24, 6), (11, 7), (15, 7), (12, 8), (13, 8)]),
        Pattern(name: "Row of ten", cells: (0..<10).map { ($0, 0) }),
    ]

    @State private var engine = LifeEngine()
    @State private var clock = StepClock()
    @State private var playing = true
    @State private var rate = 12.0
    @State private var cell = 6.0
    @State private var size: CGSize = .zero
    @State private var paint: Bool?
    @State private var pendingPattern: String? = "R-pentomino"

    private func rebuild() {
        guard size.width > 0 else { return }
        engine.setup(cols: Int(size.width / CGFloat(cell)), rows: Int(size.height / CGFloat(cell)))
        if let name = pendingPattern, let pat = Self.patterns.first(where: { $0.name == name }) { engine.place(pat.cells) }
        engine.render(rgb(accent))
    }

    var body: some View {
        ExToolPage(info: ["tool.life"]) {
            ZStack(alignment: .topLeading) {
                if let img = engine.image {
                    Image(decorative: img, scale: 1)
                        .resizable().interpolation(.none)
                        .frame(width: CGFloat(engine.cols) * CGFloat(cell), height: CGFloat(engine.rows) * CGFloat(cell))
                }
                TimelineView(.animation(paused: !active || !playing)) { tl in
                    Color.clear.onChange(of: tl.date) { _, d in
                        for _ in 0..<clock.steps(at: d, rate: rate) { engine.step() }
                        engine.render(rgb(accent))
                    }
                }
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onGeometryChange(for: CGSize.self, of: { $0.size }, action: { size = $0 })
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        let x = Int(v.location.x / CGFloat(cell)), y = Int(v.location.y / CGFloat(cell))
                        if paint == nil { paint = !engine.cell(x, y) }
                        engine.set(x, y, paint ?? true)
                        engine.render(rgb(accent))
                    }
                    .onEnded { _ in paint = nil }
            )
        } controls: {
            ExTransport(playing: $playing, onReset: { pendingPattern = "R-pentomino"; rebuild() }, onStep: {
                engine.step(); engine.render(rgb(accent))
            })
            Menu {
                ForEach(Self.patterns) { p in Button(p.name) { pendingPattern = p.name; engine.place(p.cells); engine.render(rgb(accent)) } }
                Divider()
                Button("Random (25%)") { pendingPattern = nil; engine.randomize(0.25); engine.render(rgb(accent)) }
                Button("Clear", role: .destructive) { pendingPattern = nil; engine.clear(); engine.render(rgb(accent)) }
            } label: {
                Label("Patterns", systemImage: "square.grid.3x3").frame(maxWidth: .infinity, minHeight: 30)
            }
            .buttonStyle(.glass)
            ExParamRow(title: "Speed", value: $rate, range: 1...60, step: 1, format: "%.0f/s")
            ExParamRow(title: "Cell size", value: $cell, range: 3...14, step: 1, format: "%.0f pt")
            Text("Generation \(engine.generation) · population \(engine.population). Tap or drag on the grid to draw cells.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .onChange(of: size) { _, _ in rebuild() }
        .onChange(of: cell) { _, _ in rebuild() }
        .onAppear { rebuild() }
    }
}

// MARK: - Elementary cellular automata (Rule 30, 110, …)

@Observable
private final class RuleEngine {
    private(set) var cols = 0
    private(set) var rows = 0
    private(set) var image: CGImage?
    @ObservationIgnored private var grid: [UInt8] = []
    @ObservationIgnored private var filled = 0

    func setup(cols: Int, rows: Int, random: Bool) {
        self.cols = max(8, cols); self.rows = max(8, rows)
        grid = [UInt8](repeating: 0, count: self.cols * self.rows)
        filled = 1
        if random {
            var rng = SplitMix64(state: UInt64(Date().timeIntervalSince1970 * 1000))
            for x in 0..<self.cols { grid[x] = rng.nextDouble() < 0.5 ? 1 : 0 }
        } else {
            grid[self.cols / 2] = 1
        }
    }

    func step(rule: Int) {
        guard cols > 0 else { return }
        if filled >= rows {
            // Scroll up by one row.
            grid.removeFirst(cols)
            grid.append(contentsOf: [UInt8](repeating: 0, count: cols))
            filled = rows - 1
        }
        let prev = (filled - 1) * cols, cur = filled * cols
        for x in 0..<cols {
            let l = grid[prev + (x == 0 ? cols - 1 : x - 1)], c = grid[prev + x], r = grid[prev + (x == cols - 1 ? 0 : x + 1)]
            let idx = Int(l) << 2 | Int(c) << 1 | Int(r)
            grid[cur + x] = UInt8((rule >> idx) & 1)
        }
        filled += 1
    }

    func render(_ color: (UInt8, UInt8, UInt8)) {
        image = gridImage(cols: cols, rows: rows, cells: grid, on: color)
    }
}

struct ElementaryAutomatonView: View {
    let active: Bool
    @Environment(\.appAccent) private var accent

    @State private var engine = RuleEngine()
    @State private var clock = StepClock()
    @State private var playing = true
    @State private var rate = 40.0
    @State private var cell = 4.0
    @State private var rule = 30.0
    @State private var random = false
    @State private var size: CGSize = .zero

    private var ruleNumber: Int { Int(rule.rounded()) }

    private func rebuild() {
        guard size.width > 0 else { return }
        engine.setup(cols: Int(size.width / CGFloat(cell)), rows: Int(size.height / CGFloat(cell)), random: random)
        // Fill the screen straight away; the pattern then keeps scrolling as new rows arrive.
        for _ in 1..<max(2, engine.rows) { engine.step(rule: ruleNumber) }
        engine.render(rgb(accent))
    }

    var body: some View {
        ExToolPage(info: ["tool.elementary", "tool.rule30", "tool.rule110"]) {
            ZStack(alignment: .topLeading) {
                if let img = engine.image {
                    Image(decorative: img, scale: 1)
                        .resizable().interpolation(.none)
                        .frame(width: CGFloat(engine.cols) * CGFloat(cell), height: CGFloat(engine.rows) * CGFloat(cell))
                }
                TimelineView(.animation(paused: !active || !playing)) { tl in
                    Color.clear.onChange(of: tl.date) { _, d in
                        let n = clock.steps(at: d, rate: rate)
                        guard n > 0 else { return }
                        for _ in 0..<n { engine.step(rule: ruleNumber) }
                        engine.render(rgb(accent))
                    }
                }
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onGeometryChange(for: CGSize.self, of: { $0.size }, action: { size = $0 })
        } controls: {
            ExTransport(playing: $playing, onReset: { rebuild() }, onStep: {
                engine.step(rule: ruleNumber); engine.render(rgb(accent))
            })
            ExParamRow(title: "Rule", value: $rule, range: 0...255, step: 1, format: "%.0f")
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach([30, 90, 110, 184], id: \.self) { n in
                        Button("\(n)") { rule = Double(n) }
                            .buttonStyle(.glass)
                            .frame(maxWidth: .infinity, minHeight: 30)
                    }
                }
            }
            ExParamRow(title: "Speed", value: $rate, range: 5...240, step: 5, format: "%.0f/s")
            ExParamRow(title: "Cell size", value: $cell, range: 2...10, step: 1, format: "%.0f pt")
            Toggle("Start from a random row", isOn: $random)
            Text("Rule \(ruleNumber) = \(binary(ruleNumber)) in binary. Each cell's next value depends on itself and its two neighbours.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .onChange(of: size) { _, _ in rebuild() }
        .onChange(of: cell) { _, _ in rebuild() }
        .onChange(of: random) { _, _ in rebuild() }
        .onChange(of: rule) { _, _ in rebuild() }
        .onAppear { rebuild() }
    }

    private func binary(_ n: Int) -> String {
        let s = String(n, radix: 2)
        return String(repeating: "0", count: 8 - s.count) + s
    }
}

// MARK: - Langton's ant

@Observable
private final class AntEngine {
    private(set) var cols = 0
    private(set) var rows = 0
    private(set) var steps = 0
    private(set) var image: CGImage?
    @ObservationIgnored private var grid: [UInt8] = []
    @ObservationIgnored private var x = 0
    @ObservationIgnored private var y = 0
    @ObservationIgnored private var dir = 0     // 0 up, 1 right, 2 down, 3 left

    func setup(cols: Int, rows: Int) {
        self.cols = max(8, cols); self.rows = max(8, rows)
        grid = [UInt8](repeating: 0, count: self.cols * self.rows)
        x = self.cols / 2; y = self.rows / 2; dir = 0; steps = 0
    }

    func step(_ n: Int) {
        guard cols > 0 else { return }
        for _ in 0..<n {
            let i = y * cols + x
            if grid[i] == 0 { dir = (dir + 1) & 3; grid[i] = 1 } else { dir = (dir + 3) & 3; grid[i] = 0 }
            switch dir {
            case 0: y = (y + rows - 1) % rows
            case 1: x = (x + 1) % cols
            case 2: y = (y + 1) % rows
            default: x = (x + cols - 1) % cols
            }
        }
        steps += n
    }

    func render(_ color: (UInt8, UInt8, UInt8)) {
        var rgba = [UInt8](repeating: 0, count: cols * rows * 4)
        for i in 0..<(cols * rows) where grid[i] != 0 {
            rgba[i * 4] = color.0; rgba[i * 4 + 1] = color.1; rgba[i * 4 + 2] = color.2; rgba[i * 4 + 3] = 255
        }
        // The ant itself, in white.
        let a = (y * cols + x) * 4
        rgba[a] = 255; rgba[a + 1] = 255; rgba[a + 2] = 255; rgba[a + 3] = 255
        image = Raster.cgImage(width: cols, height: rows, rgba: rgba)
    }
}

struct LangtonView: View {
    let active: Bool
    @Environment(\.appAccent) private var accent

    @State private var engine = AntEngine()
    @State private var clock = StepClock()
    @State private var playing = true
    @State private var exponent = 2.7          // steps per second = 10^exponent
    @State private var cell = 4.0
    @State private var size: CGSize = .zero

    private var rate: Double { pow(10, exponent) }

    private func rebuild() {
        guard size.width > 0 else { return }
        engine.setup(cols: Int(size.width / CGFloat(cell)), rows: Int(size.height / CGFloat(cell)))
        engine.render(rgb(accent))
    }

    var body: some View {
        ExToolPage(info: ["tool.langton"]) {
            ZStack(alignment: .topLeading) {
                if let img = engine.image {
                    Image(decorative: img, scale: 1)
                        .resizable().interpolation(.none)
                        .frame(width: CGFloat(engine.cols) * CGFloat(cell), height: CGFloat(engine.rows) * CGFloat(cell))
                }
                TimelineView(.animation(paused: !active || !playing)) { tl in
                    Color.clear.onChange(of: tl.date) { _, d in
                        // `StepClock` caps frames; run the ant in bulk instead of per-step accumulation.
                        let last = clock.last ?? d
                        clock.last = d
                        let n = Int(min(d.timeIntervalSince(last), 0.1) * rate)
                        guard n > 0 else { return }
                        engine.step(n)
                        engine.render(rgb(accent))
                    }
                }
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onGeometryChange(for: CGSize.self, of: { $0.size }, action: { size = $0 })
        } controls: {
            ExTransport(playing: $playing, onReset: { rebuild() }, onStep: {
                engine.step(1); engine.render(rgb(accent))
            })
            ExParamRow(title: "Speed", value: $exponent, range: 1...4.5, format: "10^%.1f/s")
            Text(String(format: "%.0f steps per second", rate)).font(.footnote).foregroundStyle(.secondary)
            ExParamRow(title: "Cell size", value: $cell, range: 2...10, step: 1, format: "%.0f pt")
            Text("Step \(engine.steps). On a white cell turn right, on a coloured cell turn left; flip the cell and move on. After about 10,000 steps the ant builds a diagonal \"highway\".")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .onChange(of: size) { _, _ in rebuild() }
        .onChange(of: cell) { _, _ in rebuild() }
        .onAppear { rebuild() }
    }
}
