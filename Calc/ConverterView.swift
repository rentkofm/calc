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

    private static func linear(_ coefficient: Double, _ symbol: String) -> Dimension {
        Dimension(symbol: symbol, converter: UnitConverterLinear(coefficient: coefficient))
    }

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
            UnitItem(name: "Micrometers", symbol: "µm", unit: UnitLength.micrometers),
            UnitItem(name: "Nanometers", symbol: "nm", unit: UnitLength.nanometers),
            UnitItem(name: "Furlongs", symbol: "fur", unit: UnitLength.furlongs),
            UnitItem(name: "Fathoms", symbol: "ftm", unit: UnitLength.fathoms),
            UnitItem(name: "Astronomical Units", symbol: "au", unit: UnitLength.astronomicalUnits),
            UnitItem(name: "Light Years", symbol: "ly", unit: UnitLength.lightyears),
            UnitItem(name: "Parsecs", symbol: "pc", unit: UnitLength.parsecs),
        ]),
        UnitCategory(name: "Mass", icon: "scalemass", units: [
            UnitItem(name: "Kilograms", symbol: "kg", unit: UnitMass.kilograms),
            UnitItem(name: "Grams", symbol: "g", unit: UnitMass.grams),
            UnitItem(name: "Milligrams", symbol: "mg", unit: UnitMass.milligrams),
            UnitItem(name: "Metric Tons", symbol: "t", unit: UnitMass.metricTons),
            UnitItem(name: "Pounds", symbol: "lb", unit: UnitMass.pounds),
            UnitItem(name: "Ounces", symbol: "oz", unit: UnitMass.ounces),
            UnitItem(name: "Stones", symbol: "st", unit: UnitMass.stones),
            UnitItem(name: "Micrograms", symbol: "µg", unit: UnitMass.micrograms),
            UnitItem(name: "Carats", symbol: "ct", unit: UnitMass.carats),
            UnitItem(name: "Troy Ounces", symbol: "oz t", unit: UnitMass.ouncesTroy),
            UnitItem(name: "Short Tons (US)", symbol: "tn", unit: UnitMass.shortTons),
            UnitItem(name: "Slugs", symbol: "slug", unit: UnitMass.slugs),
        ]),
        UnitCategory(name: "Temperature", icon: "thermometer.medium", units: [
            UnitItem(name: "Celsius", symbol: "°C", unit: UnitTemperature.celsius),
            UnitItem(name: "Fahrenheit", symbol: "°F", unit: UnitTemperature.fahrenheit),
            UnitItem(name: "Kelvin", symbol: "K", unit: UnitTemperature.kelvin),
            UnitItem(name: "Rankine", symbol: "°R", unit: linear(5.0 / 9.0, "°R")),
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
            UnitItem(name: "Cubic Centimeters", symbol: "cm³", unit: UnitVolume.cubicCentimeters),
            UnitItem(name: "Cubic Inches", symbol: "in³", unit: UnitVolume.cubicInches),
            UnitItem(name: "Cubic Feet", symbol: "ft³", unit: UnitVolume.cubicFeet),
            UnitItem(name: "Gallons (UK)", symbol: "gal UK", unit: UnitVolume.imperialGallons),
            UnitItem(name: "Pints (UK)", symbol: "pt UK", unit: UnitVolume.imperialPints),
            UnitItem(name: "Bushels", symbol: "bu", unit: UnitVolume.bushels),
            UnitItem(name: "Metric Cups", symbol: "cup", unit: UnitVolume.metricCups),
        ]),
        UnitCategory(name: "Area", icon: "square.dashed", units: [
            UnitItem(name: "Square Meters", symbol: "m²", unit: UnitArea.squareMeters),
            UnitItem(name: "Square Kilometers", symbol: "km²", unit: UnitArea.squareKilometers),
            UnitItem(name: "Hectares", symbol: "ha", unit: UnitArea.hectares),
            UnitItem(name: "Square Feet", symbol: "ft²", unit: UnitArea.squareFeet),
            UnitItem(name: "Square Inches", symbol: "in²", unit: UnitArea.squareInches),
            UnitItem(name: "Acres", symbol: "ac", unit: UnitArea.acres),
            UnitItem(name: "Square Miles", symbol: "mi²", unit: UnitArea.squareMiles),
            UnitItem(name: "Square Centimeters", symbol: "cm²", unit: UnitArea.squareCentimeters),
            UnitItem(name: "Square Millimeters", symbol: "mm²", unit: UnitArea.squareMillimeters),
            UnitItem(name: "Square Yards", symbol: "yd²", unit: UnitArea.squareYards),
            UnitItem(name: "Ares", symbol: "a", unit: UnitArea.ares),
        ]),
        UnitCategory(name: "Speed", icon: "speedometer", units: [
            UnitItem(name: "Meters / second", symbol: "m/s", unit: UnitSpeed.metersPerSecond),
            UnitItem(name: "Kilometers / hour", symbol: "km/h", unit: UnitSpeed.kilometersPerHour),
            UnitItem(name: "Miles / hour", symbol: "mph", unit: UnitSpeed.milesPerHour),
            UnitItem(name: "Knots", symbol: "kn", unit: UnitSpeed.knots),
            UnitItem(name: "Feet / second", symbol: "ft/s", unit: linear(0.3048, "ft/s")),
            UnitItem(name: "Mach", symbol: "Ma", unit: linear(340.29, "Ma")),
            UnitItem(name: "Speed of Light", symbol: "c", unit: linear(299_792_458, "c")),
        ]),
        UnitCategory(name: "Time", icon: "clock", units: [
            UnitItem(name: "Seconds", symbol: "s", unit: UnitDuration.seconds),
            UnitItem(name: "Milliseconds", symbol: "ms", unit: UnitDuration.milliseconds),
            UnitItem(name: "Minutes", symbol: "min", unit: UnitDuration.minutes),
            UnitItem(name: "Hours", symbol: "h", unit: UnitDuration.hours),
            UnitItem(name: "Days", symbol: "d", unit: UnitDuration(symbol: "d", converter: UnitConverterLinear(coefficient: 86_400))),
            UnitItem(name: "Weeks", symbol: "wk", unit: UnitDuration(symbol: "wk", converter: UnitConverterLinear(coefficient: 604_800))),
            UnitItem(name: "Months", symbol: "mo", unit: UnitDuration(symbol: "mo", converter: UnitConverterLinear(coefficient: 2_629_746))),
            UnitItem(name: "Years", symbol: "yr", unit: UnitDuration(symbol: "yr", converter: UnitConverterLinear(coefficient: 31_557_600))),
            UnitItem(name: "Microseconds", symbol: "µs", unit: UnitDuration.microseconds),
            UnitItem(name: "Nanoseconds", symbol: "ns", unit: UnitDuration.nanoseconds),
        ]),
        UnitCategory(name: "Data", icon: "externaldrive", units: [
            UnitItem(name: "Bytes", symbol: "B", unit: UnitInformationStorage.bytes),
            UnitItem(name: "Kilobytes", symbol: "KB", unit: UnitInformationStorage.kilobytes),
            UnitItem(name: "Megabytes", symbol: "MB", unit: UnitInformationStorage.megabytes),
            UnitItem(name: "Gigabytes", symbol: "GB", unit: UnitInformationStorage.gigabytes),
            UnitItem(name: "Terabytes", symbol: "TB", unit: UnitInformationStorage.terabytes),
            UnitItem(name: "Bits", symbol: "bit", unit: UnitInformationStorage.bits),
            UnitItem(name: "Petabytes", symbol: "PB", unit: UnitInformationStorage.petabytes),
            UnitItem(name: "Kibibytes", symbol: "KiB", unit: UnitInformationStorage.kibibytes),
            UnitItem(name: "Mebibytes", symbol: "MiB", unit: UnitInformationStorage.mebibytes),
            UnitItem(name: "Gibibytes", symbol: "GiB", unit: UnitInformationStorage.gibibytes),
            UnitItem(name: "Kilobits", symbol: "kb", unit: UnitInformationStorage.kilobits),
            UnitItem(name: "Megabits", symbol: "Mb", unit: UnitInformationStorage.megabits),
            UnitItem(name: "Gigabits", symbol: "Gb", unit: UnitInformationStorage.gigabits),
        ]),
        UnitCategory(name: "Energy", icon: "bolt", units: [
            UnitItem(name: "Joules", symbol: "J", unit: UnitEnergy.joules),
            UnitItem(name: "Kilojoules", symbol: "kJ", unit: UnitEnergy.kilojoules),
            UnitItem(name: "Calories", symbol: "cal", unit: UnitEnergy.calories),
            UnitItem(name: "Kilocalories", symbol: "kcal", unit: UnitEnergy.kilocalories),
            UnitItem(name: "Kilowatt-hours", symbol: "kWh", unit: UnitEnergy.kilowattHours),
            UnitItem(name: "Watt-hours", symbol: "Wh", unit: linear(3600, "Wh")),
            UnitItem(name: "BTU", symbol: "BTU", unit: linear(1055.05585262, "BTU")),
            UnitItem(name: "Foot-pounds", symbol: "ft·lb", unit: linear(1.3558179483314, "ft·lb")),
            UnitItem(name: "Electronvolts", symbol: "eV", unit: linear(1.602176634e-19, "eV")),
        ]),
        UnitCategory(name: "Pressure", icon: "gauge.medium", units: [
            UnitItem(name: "Pascals", symbol: "Pa", unit: UnitPressure.newtonsPerMetersSquared),
            UnitItem(name: "Kilopascals", symbol: "kPa", unit: UnitPressure.kilopascals),
            UnitItem(name: "Bars", symbol: "bar", unit: UnitPressure.bars),
            UnitItem(name: "PSI", symbol: "psi", unit: UnitPressure.poundsForcePerSquareInch),
            UnitItem(name: "mmHg", symbol: "mmHg", unit: UnitPressure.millimetersOfMercury),
            UnitItem(name: "Atmospheres", symbol: "atm", unit: linear(101_325, "atm")),
            UnitItem(name: "Torr", symbol: "Torr", unit: linear(101_325.0 / 760.0, "Torr")),
            UnitItem(name: "Hectopascals", symbol: "hPa", unit: UnitPressure.hectopascals),
            UnitItem(name: "Millibars", symbol: "mbar", unit: UnitPressure.millibars),
            UnitItem(name: "Megapascals", symbol: "MPa", unit: UnitPressure.megapascals),
            UnitItem(name: "Inches of Mercury", symbol: "inHg", unit: UnitPressure.inchesOfMercury),
        ]),
        UnitCategory(name: "Power", icon: "powerplug", units: [
            UnitItem(name: "Watts", symbol: "W", unit: UnitPower.watts),
            UnitItem(name: "Kilowatts", symbol: "kW", unit: UnitPower.kilowatts),
            UnitItem(name: "Megawatts", symbol: "MW", unit: UnitPower.megawatts),
            UnitItem(name: "Milliwatts", symbol: "mW", unit: UnitPower.milliwatts),
            UnitItem(name: "Horsepower", symbol: "hp", unit: UnitPower.horsepower),
            UnitItem(name: "BTU / hour", symbol: "BTU/h", unit: linear(0.29307107, "BTU/h")),
        ]),
        UnitCategory(name: "Force", icon: "arrow.up.right", units: [
            UnitItem(name: "Newtons", symbol: "N", unit: linear(1, "N")),
            UnitItem(name: "Kilonewtons", symbol: "kN", unit: linear(1000, "kN")),
            UnitItem(name: "Pounds-force", symbol: "lbf", unit: linear(4.4482216152605, "lbf")),
            UnitItem(name: "Kilograms-force", symbol: "kgf", unit: linear(9.80665, "kgf")),
            UnitItem(name: "Dynes", symbol: "dyn", unit: linear(1e-5, "dyn")),
            UnitItem(name: "Ounces-force", symbol: "ozf", unit: linear(0.27801385095378, "ozf")),
        ]),
        UnitCategory(name: "Angle", icon: "angle", units: [
            UnitItem(name: "Degrees", symbol: "°", unit: UnitAngle.degrees),
            UnitItem(name: "Radians", symbol: "rad", unit: UnitAngle.radians),
            UnitItem(name: "Gradians", symbol: "grad", unit: UnitAngle.gradians),
            UnitItem(name: "Arcminutes", symbol: "′", unit: UnitAngle.arcMinutes),
            UnitItem(name: "Arcseconds", symbol: "″", unit: UnitAngle.arcSeconds),
            UnitItem(name: "Revolutions", symbol: "rev", unit: UnitAngle.revolutions),
        ]),
        UnitCategory(name: "Frequency", icon: "waveform", units: [
            UnitItem(name: "Hertz", symbol: "Hz", unit: UnitFrequency.hertz),
            UnitItem(name: "Kilohertz", symbol: "kHz", unit: UnitFrequency.kilohertz),
            UnitItem(name: "Megahertz", symbol: "MHz", unit: UnitFrequency.megahertz),
            UnitItem(name: "Gigahertz", symbol: "GHz", unit: UnitFrequency.gigahertz),
            UnitItem(name: "Rev / minute", symbol: "rpm", unit: linear(1.0 / 60.0, "rpm")),
        ]),
        UnitCategory(name: "Fuel Economy", icon: "fuelpump", units: [
            UnitItem(name: "Miles / gallon (US)", symbol: "mpg", unit: UnitFuelEfficiency.milesPerGallon),
            UnitItem(name: "Miles / gallon (UK)", symbol: "mpg UK", unit: UnitFuelEfficiency.milesPerImperialGallon),
            UnitItem(name: "Liters / 100 km", symbol: "L/100km", unit: UnitFuelEfficiency.litersPer100Kilometers),
        ]),
        UnitCategory(name: "Acceleration", icon: "arrow.up.forward", units: [
            UnitItem(name: "Meters / second²", symbol: "m/s²", unit: UnitAcceleration.metersPerSecondSquared),
            UnitItem(name: "Standard Gravity", symbol: "g", unit: UnitAcceleration.gravity),
            UnitItem(name: "Feet / second²", symbol: "ft/s²", unit: linear(0.3048, "ft/s²")),
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
