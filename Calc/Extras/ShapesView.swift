import SwiftUI

/// A rotatable viewer for geometric solids: the Platonic and Archimedean solids, prisms, pyramids and the
/// curved shapes, with their vertex/edge/face counts, volume and surface area.
struct ShapesView: View {
    let active: Bool
    @Environment(\.appAccent) private var accent

    enum Shape: String, CaseIterable, Identifiable {
        case tetrahedron = "Tetrahedron", cube = "Cube", octahedron = "Octahedron"
        case dodecahedron = "Dodecahedron", icosahedron = "Icosahedron"
        case cuboctahedron = "Cuboctahedron", truncatedOctahedron = "Truncated octahedron"
        case truncatedCube = "Truncated cube", truncatedIcosahedron = "Truncated icosahedron"
        case rhombicDodecahedron = "Rhombic dodecahedron"
        case prism = "Prism", pyramid = "Pyramid", bipyramid = "Bipyramid"
        case sphere = "Sphere", cylinder = "Cylinder", cone = "Cone", torus = "Torus"
        var id: String { rawValue }

        var curved: Bool { [.sphere, .cylinder, .cone, .torus].contains(self) }
        var usesSides: Bool { [.prism, .pyramid, .bipyramid].contains(self) }
    }

    struct ShapeGroup: Identifiable {
        let title: String
        let icon: String
        let shapes: [Shape]
        var id: String { title }
    }

    static let groups: [ShapeGroup] = [
        ShapeGroup(title: "Platonic solids", icon: "cube", shapes: [.tetrahedron, .cube, .octahedron, .dodecahedron, .icosahedron]),
        ShapeGroup(title: "Archimedean & more", icon: "soccerball",
                   shapes: [.cuboctahedron, .truncatedOctahedron, .truncatedCube, .truncatedIcosahedron, .rhombicDodecahedron]),
        ShapeGroup(title: "Prisms & pyramids", icon: "pyramid", shapes: [.prism, .pyramid, .bipyramid]),
        ShapeGroup(title: "Curved solids", icon: "circle", shapes: [.sphere, .cylinder, .cone, .torus]),
    ]

    enum Style: String, CaseIterable, Identifiable {
        case solid = "Solid", both = "Solid + edges", wire = "Wireframe"
        var id: String { rawValue }
    }

    /// A solid: vertices, faces as counter-clockwise (seen from outside) index loops, and outward normals.
    struct Solid {
        var verts: [SIMD3<Double>] = []
        var faces: [[Int]] = []
        var normals: [SIMD3<Double>] = []
    }

    @State private var shape: Shape = .dodecahedron
    @State private var sides = 6.0
    @State private var tube = 0.35
    @State private var detail = 28.0
    @State private var style: Style = .both
    @State private var autoRotate = true
    @State private var yaw = 0.6
    @State private var pitch = 0.45
    @State private var zoom: CGFloat = 1
    @State private var dragOrigin: (Double, Double)?
    @State private var zoomOrigin: CGFloat?
    @State private var solid = Solid()

    // MARK: Body

    var body: some View {
        ExToolPage(info: [], panelHeight: 300) {
            TimelineView(.animation(paused: !active || !autoRotate)) { tl in
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
            Menu {
                ForEach(Self.groups) { g in
                    Menu {
                        ForEach(g.shapes) { s in Button(s.rawValue) { shape = s } }
                    } label: {
                        Label(g.title, systemImage: g.icon)
                    }
                }
            } label: {
                Label(shape.rawValue, systemImage: "cube.transparent").frame(maxWidth: .infinity, minHeight: 30)
            }
            .buttonStyle(.glass)

            Picker("Style", selection: $style) {
                ForEach(Style.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            if shape.usesSides {
                ExParamRow(title: "Sides", value: $sides, range: 3...12, step: 1, format: "%.0f")
            }
            if shape == .torus {
                ExParamRow(title: "Tube", value: $tube, range: 0.1...0.9, format: "%.2f")
            }
            if shape.curved {
                ExParamRow(title: "Detail", value: $detail, range: 8...60, step: 2, format: "%.0f")
            }
            Toggle("Auto-rotate", isOn: $autoRotate)
            Text(statsText)
                .font(.footnote).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { rebuild() }
        .onChange(of: shape) { _, _ in rebuild() }
        .onChange(of: sides) { _, _ in rebuild() }
        .onChange(of: tube) { _, _ in rebuild() }
        .onChange(of: detail) { _, _ in rebuild() }
    }

    private func rebuild() { solid = Self.build(shape, sides: Int(sides), tube: tube, detail: Int(detail)) }

    // MARK: Statistics

    private var statsText: String {
        let n = Double.pi
        switch shape {
        case .sphere:
            return "Radius 1. Volume 4π/3 ≈ \(formatNumber(4 * n / 3, digits: 5)); surface area 4π ≈ \(formatNumber(4 * n, digits: 5)). A smooth surface has no vertices, edges or faces."
        case .cylinder:
            return "Radius 1, height 2. Volume 2π ≈ \(formatNumber(2 * n, digits: 5)); surface area 6π ≈ \(formatNumber(6 * n, digits: 5)). Two circular edges, three faces."
        case .cone:
            return "Radius 1, height 2. Volume 2π/3 ≈ \(formatNumber(2 * n / 3, digits: 5)); surface area π(1 + √5) ≈ \(formatNumber(n * (1 + 5.0.squareRoot()), digits: 5)). One apex, one circular edge, two faces."
        case .torus:
            let v = 2 * n * n * tube * tube, a = 4 * n * n * tube
            return "Major radius 1, tube radius \(formatNumber(tube, digits: 3)). Volume 2π²Rr² ≈ \(formatNumber(v, digits: 5)); surface area 4π²Rr ≈ \(formatNumber(a, digits: 5)). Euler characteristic V − E + F = 0."
        default:
            guard !solid.faces.isEmpty else { return "" }
            let v = solid.verts.count
            let e = solid.faces.reduce(0) { $0 + $1.count } / 2
            let f = solid.faces.count
            var counts: [Int: Int] = [:]
            for face in solid.faces { counts[face.count, default: 0] += 1 }
            let names = [3: "triangle", 4: "quadrilateral", 5: "pentagon", 6: "hexagon", 7: "heptagon", 8: "octagon",
                         9: "nonagon", 10: "decagon", 11: "hendecagon", 12: "dodecagon"]
            let kinds = counts.keys.sorted().map { k in
                "\(counts[k]!) \(names[k] ?? "\(k)-gon")\(counts[k]! == 1 ? "" : "s")"
            }.joined(separator: ", ")
            var vol = 0.0, area = 0.0
            for face in solid.faces where face.count >= 3 {
                let a = solid.verts[face[0]]
                for k in 1..<(face.count - 1) {
                    let b = solid.verts[face[k]], c = solid.verts[face[k + 1]]
                    let cr = vcross(b - a, c - a)
                    vol += vdot(a, vcross(b, c)) / 6
                    area += 0.5 * vdot(cr, cr).squareRoot()
                }
            }
            let edgeNote = shape.usesSides ? "Base edge 1." : "Every edge has length 1."
            return "\(v) vertices, \(e) edges, \(f) faces (\(kinds)). V − E + F = \(v - e + f). \(edgeNote) Volume ≈ \(formatNumber(abs(vol), digits: 6)); surface area ≈ \(formatNumber(area, digits: 6))."
        }
    }

    // MARK: Drawing

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize, _ time: Double) {
        guard !solid.faces.isEmpty else { return }
        let spin = autoRotate ? yaw + time * 0.4 : yaw
        let (cY, sY, cP, sP) = (cos(spin), sin(spin), cos(pitch), sin(pitch))
        var radius = 1e-6
        for p in solid.verts { radius = max(radius, vdot(p, p).squareRoot()) }
        let unit = Double(min(size.width * 0.46, size.height * 0.36)) * Double(zoom) / radius
        let mid = CGPoint(x: size.width / 2, y: size.height / 2 + 24)

        // x right, up, depth (larger = farther from the viewer)
        func toView(_ p: SIMD3<Double>) -> (x: Double, up: Double, depth: Double) {
            let x1 = p.x * cY - p.y * sY
            let y1 = p.x * sY + p.y * cY
            return (x1, p.z * cP + y1 * sP, y1 * cP - p.z * sP)
        }
        let pts = solid.verts.map { v -> (screen: CGPoint, depth: Double) in
            let q = toView(v)
            return (CGPoint(x: mid.x + q.x * unit, y: mid.y - q.up * unit), q.depth)
        }

        let light = SIMD3<Double>(-0.35, 0.55, -0.75)
        let lightLen = vdot(light, light).squareRoot()
        let wire = style == .wire
        let edges = style != .solid && !shape.curved

        struct Item { var index: Int; var depth: Double; var shade: Double }
        var items: [Item] = []
        items.reserveCapacity(solid.faces.count)
        for (i, face) in solid.faces.enumerated() {
            let n = toView(solid.normals[i])
            if !wire && n.depth > 0 { continue }        // back face of a closed solid
            let depth = face.reduce(0.0) { $0 + pts[$1].depth } / Double(face.count)
            let lambert = max(0, (n.x * light.x + n.up * light.y + n.depth * light.z) / lightLen)
            items.append(Item(index: i, depth: depth, shade: lambert))
        }
        items.sort { $0.depth > $1.depth }

        for item in items {
            let face = solid.faces[item.index]
            var path = Path()
            path.move(to: pts[face[0]].screen)
            for k in 1..<face.count { path.addLine(to: pts[face[k]].screen) }
            path.closeSubpath()
            if wire {
                ctx.stroke(path, with: .color(accent.opacity(0.85)), style: StrokeStyle(lineWidth: 1.1, lineJoin: .round))
                continue
            }
            let tint = shape.curved ? Double(item.index % solid.faces.count) / Double(solid.faces.count) * 0.12
                                    : 0.11 * Double(face.count % 6)
            let colour = ExColor.shifted(accent, by: tint, sat: 0.7, bri: 0.3 + 0.7 * item.shade)
            ctx.fill(path, with: .color(colour))
            if edges {
                ctx.stroke(path, with: .color(.black.opacity(0.45)), style: StrokeStyle(lineWidth: 1.2, lineJoin: .round))
            } else {
                ctx.stroke(path, with: .color(colour), lineWidth: 0.6)
            }
        }
    }

    // MARK: Geometry

    private static let phi = (1 + 5.0.squareRoot()) / 2

    /// All distinct permutations (with every sign choice) of `base`.
    private static func signedPermutations(_ base: [Double], even: Bool = false) -> [SIMD3<Double>] {
        var out: [SIMD3<Double>] = []
        let perms: [[Int]] = even ? [[0, 1, 2], [1, 2, 0], [2, 0, 1]]
                                  : [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]
        for p in perms {
            for sx in [1.0, -1.0] { for sy in [1.0, -1.0] { for sz in [1.0, -1.0] {
                let v = SIMD3(sx * base[p[0]], sy * base[p[1]], sz * base[p[2]])
                if !out.contains(where: { dist3($0, v) < 1e-9 }) { out.append(v) }
            } } }
        }
        return out
    }

    private static func dist3(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double { vdot(a - b, a - b).squareRoot() }

    /// A convex polyhedron from its vertices alone: every plane through three vertices with all the
    /// others on one side is a face. Optionally rescaled so the shortest edge has length 1.
    private static func hull(_ input: [SIMD3<Double>], unitEdge: Bool) -> Solid {
        var v = input
        let centroid = v.reduce(SIMD3<Double>.zero, +) / Double(v.count)
        v = v.map { $0 - centroid }
        if unitEdge {
            var shortest = Double.infinity
            for i in 0..<v.count { for j in (i + 1)..<v.count { shortest = min(shortest, dist3(v[i], v[j])) } }
            v = v.map { $0 / shortest }
        }
        var seen = Set<[Int]>()
        var out = Solid(verts: v)
        let n = v.count
        for i in 0..<n {
            for j in (i + 1)..<n {
                for k in (j + 1)..<n {
                    var nrm = vcross(v[j] - v[i], v[k] - v[i])
                    let len = vdot(nrm, nrm).squareRoot()
                    guard len > 1e-9 else { continue }
                    nrm /= len
                    let d = vdot(nrm, v[i])
                    var above = false, below = false
                    var on: [Int] = []
                    for m in 0..<n {
                        let s = vdot(nrm, v[m]) - d
                        if s > 1e-7 { above = true } else if s < -1e-7 { below = true } else { on.append(m) }
                        if above && below { break }
                    }
                    if above && below { continue }
                    if !above && !below { continue }   // flat solid
                    if !seen.insert(on).inserted { continue }
                    let outward = above ? -nrm : nrm
                    // Order the face's vertices counter-clockwise as seen from outside.
                    let fc = on.reduce(SIMD3<Double>.zero) { $0 + v[$1] } / Double(on.count)
                    var u = v[on[0]] - fc
                    u -= outward * vdot(u, outward)
                    u /= max(vdot(u, u).squareRoot(), 1e-12)
                    let w = vcross(outward, u)
                    let keyed: [(Int, Double)] = on.map { m -> (Int, Double) in
                        let r = v[m] - fc
                        return (m, atan2(vdot(r, w), vdot(r, u)))
                    }
                    let ordered = keyed.sorted { $0.1 < $1.1 }.map { $0.0 }
                    out.faces.append(ordered)
                    out.normals.append(outward)
                }
            }
        }
        return out
    }

    private static func build(_ shape: Shape, sides: Int, tube: Double, detail: Int) -> Solid {
        let phi = Self.phi
        switch shape {
        case .tetrahedron:
            return hull([SIMD3(1, 1, 1), SIMD3(1, -1, -1), SIMD3(-1, 1, -1), SIMD3(-1, -1, 1)], unitEdge: true)
        case .cube:
            return hull(signedPermutations([1, 1, 1]), unitEdge: true)
        case .octahedron:
            return hull([SIMD3(1, 0, 0), SIMD3(-1, 0, 0), SIMD3(0, 1, 0), SIMD3(0, -1, 0), SIMD3(0, 0, 1), SIMD3(0, 0, -1)], unitEdge: true)
        case .dodecahedron:
            return hull(signedPermutations([1, 1, 1]) + signedPermutations([0, 1 / phi, phi], even: true), unitEdge: true)
        case .icosahedron:
            return hull(signedPermutations([0, 1, phi], even: true), unitEdge: true)
        case .cuboctahedron:
            return hull(signedPermutations([0, 1, 1]), unitEdge: true)
        case .truncatedOctahedron:
            return hull(signedPermutations([0, 1, 2]), unitEdge: true)
        case .truncatedCube:
            return hull(signedPermutations([1, 1, 2.0.squareRoot() - 1]), unitEdge: true)
        case .truncatedIcosahedron:
            var v = signedPermutations([0, 1, 3 * phi], even: true)
            v += signedPermutations([1, 2 + phi, 2 * phi], even: true)
            v += signedPermutations([phi, 2, 2 * phi + 1], even: true)
            return hull(v, unitEdge: true)
        case .rhombicDodecahedron:
            return hull(signedPermutations([1, 1, 1]) + [SIMD3(2, 0, 0), SIMD3(-2, 0, 0), SIMD3(0, 2, 0),
                                                         SIMD3(0, -2, 0), SIMD3(0, 0, 2), SIMD3(0, 0, -2)], unitEdge: true)
        case .prism:
            let r = 1 / (2 * sin(.pi / Double(sides)))
            var v: [SIMD3<Double>] = []
            for z in [-0.5, 0.5] { for k in 0..<sides {
                let a = 2 * .pi * Double(k) / Double(sides)
                v.append(SIMD3(r * cos(a), r * sin(a), z))
            } }
            return hull(v, unitEdge: false)
        case .pyramid, .bipyramid:
            let r = 1 / (2 * sin(.pi / Double(sides)))
            var v: [SIMD3<Double>] = []
            for k in 0..<sides {
                let a = 2 * .pi * Double(k) / Double(sides)
                v.append(SIMD3(r * cos(a), r * sin(a), 0))
            }
            let h = max(0.8, r)
            v.append(SIMD3(0, 0, h))
            if shape == .bipyramid { v.append(SIMD3(0, 0, -h)) }
            return hull(v, unitEdge: false)
        case .sphere:
            return latLong(detail) { _, _ in 1 }
        case .cylinder:
            return cylinder(detail)
        case .cone:
            return cone(detail)
        case .torus:
            return torus(detail, tube: tube)
        }
    }

    private static func latLong(_ n: Int, radius: (Double, Double) -> Double) -> Solid {
        let nu = max(8, n), nv = max(6, n / 2)
        var s = Solid()
        func p(_ i: Int, _ j: Int) -> SIMD3<Double> {
            let u = 2 * .pi * Double(i % nu) / Double(nu), v = .pi * Double(j) / Double(nv)
            return SIMD3(sin(v) * cos(u), sin(v) * sin(u), cos(v))
        }
        for j in 0...nv { for i in 0..<nu { s.verts.append(p(i, j)) } }
        func idx(_ i: Int, _ j: Int) -> Int { j * nu + i % nu }
        for j in 0..<nv { for i in 0..<nu {
            // Counter-clockwise from outside: increasing longitude, then increasing colatitude.
            var f = [idx(i, j), idx(i, j + 1), idx(i + 1, j + 1), idx(i + 1, j)]
            if j == 0 { f = [idx(i, j), idx(i, j + 1), idx(i + 1, j + 1)] }
            if j == nv - 1 { f = [idx(i, j), idx(i, j + 1), idx(i + 1, j)] }
            let c = f.reduce(SIMD3<Double>.zero) { $0 + s.verts[$1] } / Double(f.count)
            s.faces.append(f)
            s.normals.append(c / max(vdot(c, c).squareRoot(), 1e-12))
        } }
        return s
    }

    private static func cylinder(_ n: Int) -> Solid {
        let m = max(8, n)
        var s = Solid()
        for z in [-1.0, 1.0] { for k in 0..<m {
            let a = 2 * .pi * Double(k) / Double(m)
            s.verts.append(SIMD3(cos(a), sin(a), z))
        } }
        for k in 0..<m {
            let k1 = (k + 1) % m
            s.faces.append([k, k1, m + k1, m + k])
            let a = 2 * .pi * (Double(k) + 0.5) / Double(m)
            s.normals.append(SIMD3(cos(a), sin(a), 0))
        }
        s.faces.append(Array((0..<m).reversed())); s.normals.append(SIMD3(0, 0, -1))
        s.faces.append(Array(m..<(2 * m))); s.normals.append(SIMD3(0, 0, 1))
        return s
    }

    private static func cone(_ n: Int) -> Solid {
        let m = max(8, n)
        var s = Solid()
        for k in 0..<m {
            let a = 2 * .pi * Double(k) / Double(m)
            s.verts.append(SIMD3(cos(a), sin(a), -1))
        }
        s.verts.append(SIMD3(0, 0, 1))
        for k in 0..<m {
            let a = 2 * .pi * (Double(k) + 0.5) / Double(m)
            let nrm = SIMD3(2 * cos(a), 2 * sin(a), 1)       // radius 1, height 2
            s.faces.append([k, (k + 1) % m, m])
            s.normals.append(nrm / vdot(nrm, nrm).squareRoot())
        }
        s.faces.append(Array((0..<m).reversed())); s.normals.append(SIMD3(0, 0, -1))
        return s
    }

    private static func torus(_ n: Int, tube r: Double) -> Solid {
        let nu = max(12, n), nv = max(8, n / 2)
        var s = Solid()
        for j in 0..<nv { for i in 0..<nu {
            let u = 2 * .pi * Double(i) / Double(nu), v = 2 * .pi * Double(j) / Double(nv)
            s.verts.append(SIMD3((1 + r * cos(v)) * cos(u), (1 + r * cos(v)) * sin(u), r * sin(v)))
        } }
        func idx(_ i: Int, _ j: Int) -> Int { (j % nv) * nu + i % nu }
        for j in 0..<nv { for i in 0..<nu {
            s.faces.append([idx(i, j), idx(i + 1, j), idx(i + 1, j + 1), idx(i, j + 1)])
            let u = 2 * .pi * (Double(i) + 0.5) / Double(nu), v = 2 * .pi * (Double(j) + 0.5) / Double(nv)
            s.normals.append(SIMD3(cos(v) * cos(u), cos(v) * sin(u), sin(v)))
        } }
        return s
    }
}

private func vdot(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double { a.x * b.x + a.y * b.y + a.z * b.z }

private func vcross(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> SIMD3<Double> {
    SIMD3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
}
