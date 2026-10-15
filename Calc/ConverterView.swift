import SwiftUI

struct UnitItem: Identifiable {
    let name: String
    let symbol: String
    let unit: Dimension
    var id: String { name }
}

struct UnitCategory: Identifiable {
    let name: String
    let icon: String
    let units: [UnitItem]
    var id: String { name }

    static let all: [UnitCategory] = [
        UnitCategory(name: "Length", icon: "ruler", units: [
            UnitItem(name: "Meters", symbol: "m", unit: UnitLength.meters),
            UnitItem(name: "Kilometers", symbol: "km", unit: UnitLength.kilometers),
            UnitItem(name: "Centimeters", symbol: "cm", unit: UnitLength.centimeters),
            UnitItem(name: "Millimeters", symbol: "mm", unit: UnitLength.millimeters),
            UnitItem(name: "Miles", symbol: "mi", unit: UnitLength.miles),
            UnitItem(name: "Yards", symbol: "yd", unit: UnitLength.yards),
            UnitItem(name: "Feet", symbol: "ft", unit: UnitLength.feet),
            UnitItem(name: "Inches", symbol: "in", unit: UnitLength.inches),
            UnitItem(name: "Nautical Miles", symbol: "nmi", unit: UnitLength.nauticalMiles),
        ]),
        UnitCategory(name: "Mass", icon: "scalemass", units: [
            UnitItem(name: "Kilograms", symbol: "kg", unit: UnitMass.kilograms),
            UnitItem(name: "Grams", symbol: "g", unit: UnitMass.grams),
            UnitItem(name: "Milligrams", symbol: "mg", unit: UnitMass.milligrams),
            UnitItem(name: "Metric Tons", symbol: "t", unit: UnitMass.metricTons),
            UnitItem(name: "Pounds", symbol: "lb", unit: UnitMass.pounds),
            UnitItem(name: "Ounces", symbol: "oz", unit: UnitMass.ounces),
            UnitItem(name: "Stones", symbol: "st", unit: UnitMass.stones),
        ]),
        UnitCategory(name: "Temperature", icon: "thermometer.medium", units: [
            UnitItem(name: "Celsius", symbol: "°C", unit: UnitTemperature.celsius),
            UnitItem(name: "Fahrenheit", symbol: "°F", unit: UnitTemperature.fahrenheit),
            UnitItem(name: "Kelvin", symbol: "K", unit: UnitTemperature.kelvin),
        ]),
        UnitCategory(name: "Volume", icon: "drop", units: [
            UnitItem(name: "Liters", symbol: "L", unit: UnitVolume.liters),
            UnitItem(name: "Milliliters", symbol: "mL", unit: UnitVolume.milliliters),
            UnitItem(name: "Cubic Meters", symbol: "m³", unit: UnitVolume.cubicMeters),
            UnitItem(name: "Gallons (US)", symbol: "gal", unit: UnitVolume.gallons),
            UnitItem(name: "Quarts", symbol: "qt", unit: UnitVolume.quarts),
            UnitItem(name: "Pints", symbol: "pt", unit: UnitVolume.pints),
            UnitItem(name: "Cups", symbol: "cup", unit: UnitVolume.cups),
            UnitItem(name: "Fluid Ounces", symbol: "fl oz", unit: UnitVolume.fluidOunces),
            UnitItem(name: "Tablespoons", symbol: "tbsp", unit: UnitVolume.tablespoons),
            UnitItem(name: "Teaspoons", symbol: "tsp", unit: UnitVolume.teaspoons),
        ]),
        UnitCategory(name: "Area", icon: "square.dashed", units: [
            UnitItem(name: "Square Meters", symbol: "m²", unit: UnitArea.squareMeters),
            UnitItem(name: "Square Kilometers", symbol: "km²", unit: UnitArea.squareKilometers),
            UnitItem(name: "Hectares", symbol: "ha", unit: UnitArea.hectares),
            UnitItem(name: "Square Feet", symbol: "ft²", unit: UnitArea.squareFeet),
            UnitItem(name: "Square Inches", symbol: "in²", unit: UnitArea.squareInches),
            UnitItem(name: "Acres", symbol: "ac", unit: UnitArea.acres),
            UnitItem(name: "Square Miles", symbol: "mi²", unit: UnitArea.squareMiles),
        ]),
        UnitCategory(name: "Speed", icon: "speedometer", units: [
            UnitItem(name: "Meters / second", symbol: "m/s", unit: UnitSpeed.metersPerSecond),
            UnitItem(name: "Kilometers / hour", symbol: "km/h", unit: UnitSpeed.kilometersPerHour),
            UnitItem(name: "Miles / hour", symbol: "mph", unit: UnitSpeed.milesPerHour),
            UnitItem(name: "Knots", symbol: "kn", unit: UnitSpeed.knots),
        ]),
        UnitCategory(name: "Time", icon: "clock", units: [
            UnitItem(name: "Seconds", symbol: "s", unit: UnitDuration.seconds),
            UnitItem(name: "Milliseconds", symbol: "ms", unit: UnitDuration.milliseconds),
            UnitItem(name: "Minutes", symbol: "min", unit: UnitDuration.minutes),
            UnitItem(name: "Hours", symbol: "h", unit: UnitDuration.hours),
            UnitItem(name: "Days", symbol: "d", unit: UnitDuration(symbol: "d", converter: UnitConverterLinear(coefficient: 86_400))),
            UnitItem(name: "Weeks", symbol: "wk", unit: UnitDuration(symbol: "wk", converter: UnitConverterLinear(coefficient: 604_800))),
        ]),
        UnitCategory(name: "Data", icon: "externaldrive", units: [
            UnitItem(name: "Bytes", symbol: "B", unit: UnitInformationStorage.bytes),
            UnitItem(name: "Kilobytes", symbol: "KB", unit: UnitInformationStorage.kilobytes),
            UnitItem(name: "Megabytes", symbol: "MB", unit: UnitInformationStorage.megabytes),
            UnitItem(name: "Gigabytes", symbol: "GB", unit: UnitInformationStorage.gigabytes),
            UnitItem(name: "Terabytes", symbol: "TB", unit: UnitInformationStorage.terabytes),
            UnitItem(name: "Bits", symbol: "bit", unit: UnitInformationStorage.bits),
        ]),
        UnitCategory(name: "Energy", icon: "bolt", units: [
            UnitItem(name: "Joules", symbol: "J", unit: UnitEnergy.joules),
            UnitItem(name: "Kilojoules", symbol: "kJ", unit: UnitEnergy.kilojoules),
            UnitItem(name: "Calories", symbol: "cal", unit: UnitEnergy.calories),
            UnitItem(name: "Kilocalories", symbol: "kcal", unit: UnitEnergy.kilocalories),
            UnitItem(name: "Kilowatt-hours", symbol: "kWh", unit: UnitEnergy.kilowattHours),
        ]),
        UnitCategory(name: "Pressure", icon: "gauge.medium", units: [
            UnitItem(name: "Pascals", symbol: "Pa", unit: UnitPressure.newtonsPerMetersSquared),
            UnitItem(name: "Kilopascals", symbol: "kPa", unit: UnitPressure.kilopascals),
            UnitItem(name: "Bars", symbol: "bar", unit: UnitPressure.bars),
            UnitItem(name: "PSI", symbol: "psi", unit: UnitPressure.poundsForcePerSquareInch),
            UnitItem(name: "mmHg", symbol: "mmHg", unit: UnitPressure.millimetersOfMercury),
        ]),
    ]
}

struct ConverterView: View {
    @Environment(\.appAccent) private var accent
    @AppStorage("precision") private var precision = 12

    @State private var category = UnitCategory.all[0]
    @State private var fromID = UnitCategory.all[0].units[0].id
    @State private var toID = UnitCategory.all[0].units[4].id
    @State private var input = "1"
    @FocusState private var inputFocused: Bool

    private var from: UnitItem { category.units.first { $0.id == fromID } ?? category.units[0] }
    private var to: UnitItem { category.units.first { $0.id == toID } ?? category.units[1] }

    private var value: Double? { Double(input.replacingOccurrences(of: ",", with: ".")) }

    private func convert(_ v: Double, to target: UnitItem) -> Double {
        let base = from.unit.converter.baseUnitValue(fromValue: v)
        return target.unit.converter.value(fromBaseUnitValue: base)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    categoryChips
                    converterCard
                    allUnitsCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background { AppBackground() }
            .navigationTitle("Convert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { inputFocused = false }
                }
            }
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(UnitCategory.all) { cat in
                        let selected = cat.id == category.id
                        Button {
                            category = cat
                            fromID = cat.units[0].id
                            toID = cat.units[min(1, cat.units.count - 1)].id
                        } label: {
                            Label(cat.name, systemImage: cat.icon)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(selected ? Color.white : Color.primary)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 38)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(selected ? .regular.tint(accent).interactive() : .regular.interactive(),
                                     in: Capsule())
                    }
                }
            }
        }
    }

    private var converterCard: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                unitMenu(selection: $fromID)
                TextField("0", text: $input)
                    .font(.system(size: 44, weight: .light, design: .rounded))
                    .keyboardType(.decimalPad)
                    .focused($inputFocused)
                    .minimumScaleFactor(0.4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)

            HStack {
                Divider()
                Button {
                    let previous = fromID
                    withAnimation(.smooth) { fromID = toID; toID = previous }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(accent).interactive(), in: Circle())
                Divider()
            }
            .frame(height: 40)

            VStack(alignment: .leading, spacing: 6) {
                unitMenu(selection: $toID)
                Text(value.map { formatNumber(convert($0, to: to), digits: precision) } ?? "—")
                    .font(.system(size: 44, weight: .light, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
    }

    private func unitMenu(selection: Binding<String>) -> some View {
        Picker("Unit", selection: selection) {
            ForEach(category.units) { u in Text("\(u.name) (\(u.symbol))").tag(u.id) }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .tint(accent)
        .fixedSize()
        .offset(x: -8)
    }

    private var allUnitsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("All \(category.name) Units")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
            ForEach(category.units) { u in
                HStack {
                    Text(u.name)
                    Spacer()
                    Text(value.map { "\(formatNumber(convert($0, to: u), digits: min(precision, 9))) \(u.symbol)" } ?? "—")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .padding(.vertical, 10)
                if u.id != category.units.last?.id { Divider() }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
    }
}
