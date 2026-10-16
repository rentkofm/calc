import SwiftUI

/// Rotatable parametric surfaces drawn with a small painter's-algorithm renderer.
/// `minimal == false`: Möbius strip and Klein bottle. `minimal == true`: catenoid ↔ helicoid, Enneper, Scherk.
struct SurfacesView: View {
    let active: Bool
    let minimal: Bool
    @Environment(\.appAccent) private var accent

    enum Surface: String, CaseIterable, Identifiable {
        case mobius = "Möbius strip", klein = "Klein bottle"
        case catenoid = "Catenoid ↔ Helicoid", enneper = "Enneper", scherk = "Scherk"
        var id: String { rawValue }
        var infoKeys: [String] {
            switch self {
            case .mobius: return ["tool.mobius"]
            case .klein: return ["tool.klein"]
            case .catenoid: return ["tool.minimal", "tool.catenoid", "tool.helicoid"]
            case .enneper: return ["tool.minimal", "tool.enneper"]
            case .scherk: return ["tool.minimal", "tool.scherk"]
            }
        }
    }

    @State private var surface: Surface

    init(active: Bool, minimal: Bool) {
        self.active = active
        self.minimal = minimal
        _surface = State(initialValue: minimal ? .catenoid : .mobius)
    }
    // Möbius
    @State private var halfWidth = 0.6
    @State private var twists = 1.0
    // Klein
    @State private var cut = 0.85
    @State private var minimalCut = 1.0
    // Minimal surfaces
    @State private var theta = Double.pi / 2
    @State private var animateMorph = true
    @State private var extent = 1.5
    // Shared
    @State private var resolution = 36.0
    @State private var wire = false
    @State private var autoRotate = true
    @State private var yaw = 0.7
    @State private var pitch = 0.5
    @State private var zoom: CGFloat = 1
    @State private var dragOrigin: (Double, Double)?
    @State private var zoomOrigin: CGFloat?

    private var choices: [Surface] { minimal ? [.catenoid, .enneper, .scherk] : [.mobius, .klein] }

    // MARK: Geometry

    private struct Mesh {
        var points: [SIMD3<Double>]   // (nu + 1) × (nv + 1)
        var nu: Int
        var nv: Int
    }

    private func mesh(morph: Double) -> Mesh {
        let nu = Int(resolution) * 2, nv = Int(resolution)
        var pts: [SIMD3<Double>] = []
        pts.reserveCapacity((nu + 1) * (nv + 1))
        for j in 0...nv {
            let fv = Double(j) / Double(nv)
            for i in 0...nu {
                let fu = Double(i) / Double(nu)
                pts.append(point(fu, fv, morph: morph))
            }
        }
        return Mesh(points: pts, nu: nu, nv: nv)
    }

    /// Surface point for fractions (fu, fv) of the parameter rectangle.
    private func point(_ fu: Double, _ fv: Double, morph: Double) -> SIMD3<Double> {
        switch surface {
        case .mobius:
            let u = 2 * .pi * fu, v = 2 * fv - 1
            let r = 1 + halfWidth * v * cos(twists * u / 2)
            return SIMD3(r * cos(u), r * sin(u), halfWidth * v * sin(twists * u / 2))
        case .klein:
            let u = 2 * .pi * cut * fu, v = 2 * .pi * fv
            let a = 2.0
            let r = a + cos(u / 2) * sin(v) - sin(u / 2) * sin(2 * v)
            return SIMD3(r * cos(u), r * sin(u), sin(u / 2) * sin(v) + cos(u / 2) * sin(2 * v))
        case .catenoid:
            let u = -Double.pi + 2 * .pi * minimalCut * fu, v = -1.5 + 3 * fv
            let c = cos(morph), s = sin(morph)
            return SIMD3(c * sinh(v) * sin(u) + s * cosh(v) * cos(u),
                         -c * sinh(v) * cos(u) + s * cosh(v) * sin(u),
                         u * c + v * s)
        case .enneper:
            let u = -extent + 2 * extent * fu, v = -extent + 2 * extent * fv
            return SIMD3(u - u * u * u / 3 + u * v * v, v - v * v * v / 3 + v * u * u, u * u - v * v)
        case .scherk:
            let x = -1.35 + 2.7 * fu, y = -1.35 + 2.7 * fv
            return SIMD3(x, y, log(cos(y) / cos(x)))
        }
    }

    // MARK: Body

    var body: some View {
        ExToolPage(info: surface.infoKeys, panelHeight: 270) {
            TimelineView(.animation(paused: !active || !(autoRotate || (surface == .catenoid && animateMorph)))) { tl in
                Canvas { ctx, size in draw(&ctx, size, tl.date.timeIntervalSinceReferenceDate) }
            }
            .gesture(
                DragGesture()
                    .onChanged { v in
                        if dragOrigin == nil { dragOrigin = (yaw, pitch) }
                        let o = dragOrigin ?? (yaw, pitch)
                        yaw = o.0 + Double(v.translation.width) * 0.01
                        pitch = min(max(o.1 + Double(v.translation.height) * 0.01, -1.5), 1.5)
                    }
                    .onEnded { _ in dragOrigin = nil }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { v in
                        if zoomOrigin == nil { zoomOrigin = zoom }
                        zoom = min(max((zoomOrigin ?? zoom) * v.magnification, 0.4), 6)
                    }
                    .onEnded { _ in zoomOrigin = nil }
            )
        } controls: {
            Picker("Surface", selection: $surface) {
                ForEach(choices) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            switch surface {
            case .mobius:
                ExParamRow(title: "Width", value: $halfWidth, range: 0.1...1.2, format: "%.2f")
                ExParamRow(title: "Half-twists", value: $twists, range: -4...4, step: 1, format: "%.0f")
                Text(Int(twists) % 2 == 0 ? "An even number of half-twists gives an ordinary two-sided band."
                                          : "An odd number of half-twists gives a Möbius strip: one side, one edge.")
                    .font(.footnote).foregroundStyle(.secondary)
            case .klein:
                ExParamRow(title: "Cutaway", value: $cut, range: 0.3...1, format: "%.2f")
                Text("Figure-eight immersion. In 3D it must pass through itself; a true Klein bottle needs 4D. Lower the cutaway to look inside.")
                    .font(.footnote).foregroundStyle(.secondary)
            case .catenoid:
                Toggle("Animate the bending", isOn: $animateMorph)
                ExParamRow(title: "Morph θ", value: $theta, range: 0...(Double.pi / 2), format: "%.2f")
                    .disabled(animateMorph)
                ExParamRow(title: "Cutaway", value: $minimalCut, range: 0.3...1, format: "%.2f")
                Text("θ = 0 is a helicoid, θ = π/2 a catenoid. Every step in between is also a minimal surface, with the same area elements.")
                    .font(.footnote).foregroundStyle(.secondary)
            case .enneper:
                ExParamRow(title: "Extent", value: $extent, range: 0.6...2.2, format: "%.2f")
                Text("Enneper's surface is a self-intersecting minimal surface; larger extents show the self-intersection.")
                    .font(.footnote).foregroundStyle(.secondary)
            case .scherk:
                Text("Scherk's first surface: z = ln(cos y / cos x). A doubly periodic minimal surface; one period is shown.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            ExParamRow(title: "Detail", value: $resolution, range: 12...70, step: 2, format: "%.0f")
            Toggle("Wireframe", isOn: $wire)
            Toggle("Auto-rotate", isOn: $autoRotate)
        }
    }

    // MARK: Drawing

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize, _ time: Double) {
        let morph = surface == .catenoid ? (animateMorph ? (0.5 + 0.5 * sin(time * 0.5)) * .pi / 2 : theta) : theta
        let spin = autoRotate ? yaw + time * 0.3 : yaw
        let m = mesh(morph: morph)

        // Fit: centre and radius of the bounding box.
        var lo = m.points[0], hi = m.points[0]
        for p in m.points { lo = pointwiseMin(lo, p); hi = pointwiseMax(hi, p) }
        let centre = (lo + hi) / 2
        let radius = max(1e-6, ((hi - lo) / 2).max() * 1.1)
        let unit = Double(min(size.width * 0.46, size.height * 0.36)) * Double(zoom) / radius
        let mid = CGPoint(x: size.width / 2, y: size.height / 2 + 24)

        let (cY, sY, cP, sP) = (cos(spin), sin(spin), cos(pitch), sin(pitch))
        func view(_ p: SIMD3<Double>) -> (screen: CGPoint, depth: Double) {
            let q = p - centre
            let x1 = q.x * cY - q.y * sY
            let y1 = q.x * sY + q.y * cY
            return (CGPoint(x: mid.x + x1 * unit, y: mid.y - (q.z * cP + y1 * sP) * unit), y1 * cP - q.z * sP)
        }
        func viewNormal(_ n: SIMD3<Double>) -> Double {
            let y1 = n.x * sY + n.y * cY
            return y1 * cP - n.z * sP          // component along the view direction
        }

        let projected = m.points.map(view)
        struct Face { var i: Int; var j: Int; var depth: Double; var shade: Double }
        var faces: [Face] = []
        faces.reserveCapacity(m.nu * m.nv)
        let stride = m.nu + 1
        for j in 0..<m.nv {
            for i in 0..<m.nu {
                let a = j * stride + i, b = a + 1, c = a + stride + 1, d = a + stride
                let pa = m.points[a], pb = m.points[b], pc = m.points[c], pd = m.points[d]
                var n = cross3(pc - pa, pd - pb)
                let len = (n.x * n.x + n.y * n.y + n.z * n.z).squareRoot()
                guard len.isFinite, len > 1e-12 else { continue }
                n /= len
                let depth = (projected[a].depth + projected[b].depth + projected[c].depth + projected[d].depth) / 4
                guard depth.isFinite else { continue }
                faces.append(Face(i: i, j: j, depth: depth, shade: abs(viewNormal(n))))
            }
        }
        faces.sort { $0.depth > $1.depth }     // far to near

        for f in faces {
            let a = f.j * stride + f.i
            var path = Path()
            path.move(to: projected[a].screen)
            path.addLine(to: projected[a + 1].screen)
            path.addLine(to: projected[a + stride + 1].screen)
            path.addLine(to: projected[a + stride].screen)
            path.closeSubpath()
            if wire {
                ctx.stroke(path, with: .color(accent.opacity(0.8)), lineWidth: 0.6)
            } else {
                let along = Double(f.i) / Double(m.nu)
                let colour = ExColor.shifted(accent, by: 0.18 * along, sat: 0.7, bri: 0.35 + 0.65 * f.shade)
                ctx.fill(path, with: .color(colour))
                ctx.stroke(path, with: .color(colour), lineWidth: 0.5)
            }
        }
    }
}

private func cross3(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> SIMD3<Double> {
    SIMD3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
}
