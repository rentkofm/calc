// All 118 elements.
// [symbol, name, atomic mass, electronegativity, melting K, boiling K, density g/cm³, year (0 = ancient), phase (s/l/g/u), electron configuration, summary]
const RAW = [
  ["H", "Hydrogen", 1.008, 2.20, 13.99, 20.27, 0.00008988, 1766, "g", "1s1", "The lightest and most abundant element in the universe."],
  ["He", "Helium", 4.0026, null, null, 4.22, 0.0001785, 1868, "g", "1s2", "Stays liquid down to absolute zero at normal pressure; found first in the Sun."],
  ["Li", "Lithium", 6.94, 0.98, 453.65, 1603, 0.534, 1817, "s", "[He] 2s1", "The lightest metal, and the heart of rechargeable batteries."],
  ["Be", "Beryllium", 9.0122, 1.57, 1560, 2742, 1.85, 1798, "s", "[He] 2s2", "Light, stiff and toxic; used in aerospace and X-ray windows."],
  ["B", "Boron", 10.81, 2.04, 2349, 4200, 2.34, 1808, "s", "[He] 2s2 2p1", "An essential plant nutrient found in heat-proof borosilicate glass."],
  ["C", "Carbon", 12.011, 2.55, 3800, 4300, 2.267, 0, "s", "[He] 2s2 2p2", "The basis of all known life; forms diamond, graphite and graphene."],
  ["N", "Nitrogen", 14.007, 3.04, 63.15, 77.36, 0.0012506, 1772, "g", "[He] 2s2 2p3", "Makes up 78% of Earth's atmosphere and is vital to proteins and DNA."],
  ["O", "Oxygen", 15.999, 3.44, 54.36, 90.19, 0.001429, 1774, "g", "[He] 2s2 2p4", "Essential for respiration and combustion; about 21% of the air."],
  ["F", "Fluorine", 18.998, 3.98, 53.53, 85.03, 0.001696, 1886, "g", "[He] 2s2 2p5", "The most electronegative and reactive of all elements."],
  ["Ne", "Neon", 20.180, null, 24.56, 27.07, 0.0008999, 1898, "g", "[He] 2s2 2p6", "Glows red-orange in discharge tubes — the classic neon sign."],
  ["Na", "Sodium", 22.990, 0.93, 370.87, 1156, 0.971, 1807, "s", "[Ne] 3s1", "A soft metal that reacts violently with water; half of table salt."],
  ["Mg", "Magnesium", 24.305, 1.31, 923, 1363, 1.738, 1755, "s", "[Ne] 3s2", "Burns with a brilliant white flame; a lightweight structural metal."],
  ["Al", "Aluminium", 26.982, 1.61, 933.47, 2792, 2.70, 1825, "s", "[Ne] 3s2 3p1", "The most abundant metal in Earth's crust — light and corrosion resistant."],
  ["Si", "Silicon", 28.085, 1.90, 1687, 3538, 2.329, 1824, "s", "[Ne] 3s2 3p2", "The backbone of modern electronics, glass and sand."],
  ["P", "Phosphorus", 30.974, 2.19, 317.3, 553.7, 1.82, 1669, "s", "[Ne] 3s2 3p3", "Essential to DNA and ATP; the first element discovered by chemistry."],
  ["S", "Sulfur", 32.06, 2.58, 388.36, 717.87, 2.067, 0, "s", "[Ne] 3s2 3p4", "Yellow brimstone, used to make sulfuric acid and vulcanise rubber."],
  ["Cl", "Chlorine", 35.45, 3.16, 171.6, 239.11, 0.003214, 1774, "g", "[Ne] 3s2 3p5", "Disinfects drinking water and pools."],
  ["Ar", "Argon", 39.948, null, 83.8, 87.30, 0.0017837, 1894, "g", "[Ne] 3s2 3p6", "An inert gas that fills light bulbs and shields welds."],
  ["K", "Potassium", 39.098, 0.82, 336.53, 1032, 0.862, 1807, "s", "[Ar] 4s1", "Vital for nerves and muscles; found in bananas and fertiliser."],
  ["Ca", "Calcium", 40.078, 1.00, 1115, 1757, 1.55, 1808, "s", "[Ar] 4s2", "Builds bones and teeth; abundant in limestone and chalk."],
  ["Sc", "Scandium", 44.956, 1.36, 1814, 3109, 2.985, 1879, "s", "[Ar] 3d1 4s2", "Strengthens aluminium alloys used in sports gear and aircraft."],
  ["Ti", "Titanium", 47.867, 1.54, 1941, 3560, 4.506, 1791, "s", "[Ar] 3d2 4s2", "Strong, light and biocompatible — used in implants and jets."],
  ["V", "Vanadium", 50.942, 1.63, 2183, 3680, 6.0, 1801, "s", "[Ar] 3d3 4s2", "Toughens steel; its compounds come in many bright colours."],
  ["Cr", "Chromium", 51.996, 1.66, 2180, 2944, 7.15, 1797, "s", "[Ar] 3d5 4s1", "Gives stainless steel its shine and rubies their red."],
  ["Mn", "Manganese", 54.938, 1.55, 1519, 2334, 7.21, 1774, "s", "[Ar] 3d5 4s2", "Essential for steelmaking and alkaline batteries."],
  ["Fe", "Iron", 55.845, 1.83, 1811, 3134, 7.874, 0, "s", "[Ar] 3d6 4s2", "The core of steel — and of Earth itself."],
  ["Co", "Cobalt", 58.933, 1.88, 1768, 3200, 8.90, 1735, "s", "[Ar] 3d7 4s2", "Gives deep blue pigments and powers lithium-ion batteries."],
  ["Ni", "Nickel", 58.693, 1.91, 1728, 3186, 8.908, 1751, "s", "[Ar] 3d8 4s2", "A corrosion-resistant metal used in coins and stainless steel."],
  ["Cu", "Copper", 63.546, 1.90, 1357.77, 2835, 8.96, 0, "s", "[Ar] 3d10 4s1", "An excellent conductor and one of the first metals ever worked."],
  ["Zn", "Zinc", 65.38, 1.65, 692.68, 1180, 7.14, 1746, "s", "[Ar] 3d10 4s2", "Galvanises steel against rust and is an essential trace nutrient."],
  ["Ga", "Gallium", 69.723, 1.81, 302.91, 2477, 5.91, 1875, "s", "[Ar] 3d10 4s2 4p1", "Melts in your hand; used in LEDs and fast chips."],
  ["Ge", "Germanium", 72.630, 2.01, 1211.4, 3106, 5.323, 1886, "s", "[Ar] 3d10 4s2 4p2", "The semiconductor of early transistors and fibre optics."],
  ["As", "Arsenic", 74.922, 2.18, null, 887, 5.727, 1250, "s", "[Ar] 3d10 4s2 4p3", "A notorious poison that is also a vital semiconductor dopant."],
  ["Se", "Selenium", 78.971, 2.55, 494, 958, 4.81, 1817, "s", "[Ar] 3d10 4s2 4p4", "Light-sensitive, and an essential trace nutrient."],
  ["Br", "Bromine", 79.904, 2.96, 265.8, 332.0, 3.122, 1826, "l", "[Ar] 3d10 4s2 4p5", "One of only two elements that are liquid at room temperature."],
  ["Kr", "Krypton", 83.798, 3.00, 115.79, 119.93, 0.003733, 1898, "g", "[Ar] 3d10 4s2 4p6", "A noble gas used in high-performance lighting and lasers."],
  ["Rb", "Rubidium", 85.468, 0.82, 312.46, 961, 1.532, 1861, "s", "[Kr] 5s1", "A soft, highly reactive metal used in atomic clocks."],
  ["Sr", "Strontium", 87.62, 0.95, 1050, 1655, 2.64, 1790, "s", "[Kr] 5s2", "Burns crimson red in fireworks."],
  ["Y", "Yttrium", 88.906, 1.22, 1799, 3609, 4.472, 1794, "s", "[Kr] 4d1 5s2", "Makes red phosphors and high-temperature superconductors."],
  ["Zr", "Zirconium", 91.224, 1.33, 2128, 4682, 6.511, 1789, "s", "[Kr] 4d2 5s2", "Resists corrosion and neutrons, so it lines nuclear reactors."],
  ["Nb", "Niobium", 92.906, 1.6, 2750, 5017, 8.57, 1801, "s", "[Kr] 4d4 5s1", "Makes the superconducting magnets in MRI scanners."],
  ["Mo", "Molybdenum", 95.95, 2.16, 2896, 4912, 10.28, 1778, "s", "[Kr] 4d5 5s1", "Hardens steel and survives extreme heat."],
  ["Tc", "Technetium", 98, 1.9, 2430, 4538, 11.0, 1937, "s", "[Kr] 4d5 5s2", "The first artificially produced element; used in medical imaging."],
  ["Ru", "Ruthenium", 101.07, 2.2, 2607, 4423, 12.45, 1844, "s", "[Kr] 4d7 5s1", "A hard platinum-group metal for durable electrical contacts."],
  ["Rh", "Rhodium", 102.91, 2.28, 2237, 3968, 12.41, 1803, "s", "[Kr] 4d8 5s1", "Rare and reflective; cleans exhaust in catalytic converters."],
  ["Pd", "Palladium", 106.42, 2.20, 1828.05, 3236, 12.023, 1803, "s", "[Kr] 4d10", "Soaks up hydrogen like a sponge and catalyses many reactions."],
  ["Ag", "Silver", 107.87, 1.93, 1234.93, 2435, 10.49, 0, "s", "[Kr] 4d10 5s1", "The best electrical and thermal conductor of any metal."],
  ["Cd", "Cadmium", 112.41, 1.69, 594.22, 1040, 8.65, 1817, "s", "[Kr] 4d10 5s2", "A toxic metal used in nickel–cadmium batteries."],
  ["In", "Indium", 114.82, 1.78, 429.75, 2345, 7.31, 1863, "s", "[Kr] 4d10 5s2 5p1", "A soft metal that coats touchscreens."],
  ["Sn", "Tin", 118.71, 1.96, 505.08, 2875, 7.287, 0, "s", "[Kr] 4d10 5s2 5p2", "Alloyed with copper to make bronze, and used to plate cans."],
  ["Sb", "Antimony", 121.76, 2.05, 903.78, 1860, 6.685, 0, "s", "[Kr] 4d10 5s2 5p3", "Added to alloys and flame retardants."],
  ["Te", "Tellurium", 127.60, 2.1, 722.66, 1261, 6.232, 1782, "s", "[Kr] 4d10 5s2 5p4", "Rarer than gold in the crust; used in solar panels."],
  ["I", "Iodine", 126.90, 2.66, 386.85, 457.4, 4.93, 1811, "s", "[Kr] 4d10 5s2 5p5", "Essential for thyroid hormones; sublimes into a violet vapour."],
  ["Xe", "Xenon", 131.29, 2.6, 161.4, 165.05, 0.005887, 1898, "g", "[Kr] 4d10 5s2 5p6", "Powers ion thrusters and ultra-bright headlamps."],
  ["Cs", "Caesium", 132.91, 0.79, 301.59, 944, 1.873, 1860, "s", "[Xe] 6s1", "Its atomic clocks define the length of a second."],
  ["Ba", "Barium", 137.33, 0.89, 1000, 2170, 3.594, 1808, "s", "[Xe] 6s2", "Barium meals help X-rays; burns green in fireworks."],
  ["La", "Lanthanum", 138.91, 1.10, 1193, 3737, 6.145, 1839, "s", "[Xe] 5d1 6s2", "Namesake of the lanthanides; sharpens camera lenses."],
  ["Ce", "Cerium", 140.12, 1.12, 1068, 3716, 6.770, 1803, "s", "[Xe] 4f1 5d1 6s2", "The most abundant rare earth; sparks in lighter flints."],
  ["Pr", "Praseodymium", 140.91, 1.13, 1208, 3793, 6.773, 1885, "s", "[Xe] 4f3 6s2", "Tints glass and ceramics a yellow-green."],
  ["Nd", "Neodymium", 144.24, 1.14, 1297, 3347, 7.007, 1885, "s", "[Xe] 4f4 6s2", "Makes the strongest permanent magnets."],
  ["Pm", "Promethium", 145, null, 1315, 3273, 7.26, 1945, "s", "[Xe] 4f5 6s2", "Radioactive; once used in glow-in-the-dark paint."],
  ["Sm", "Samarium", 150.36, 1.17, 1345, 2067, 7.52, 1879, "s", "[Xe] 4f6 6s2", "Used in high-temperature magnets."],
  ["Eu", "Europium", 151.96, null, 1099, 1802, 5.243, 1901, "s", "[Xe] 4f7 6s2", "Red and blue phosphors in screens and euro banknotes."],
  ["Gd", "Gadolinium", 157.25, 1.20, 1585, 3546, 7.895, 1880, "s", "[Xe] 4f7 5d1 6s2", "A contrast agent for MRI scans."],
  ["Tb", "Terbium", 158.93, null, 1629, 3503, 8.229, 1843, "s", "[Xe] 4f9 6s2", "Green phosphors in displays and lighting."],
  ["Dy", "Dysprosium", 162.50, 1.22, 1680, 2840, 8.55, 1886, "s", "[Xe] 4f10 6s2", "Keeps magnets strong at high temperatures."],
  ["Ho", "Holmium", 164.93, 1.23, 1734, 2993, 8.795, 1878, "s", "[Xe] 4f11 6s2", "Has the highest magnetic strength of any element."],
  ["Er", "Erbium", 167.26, 1.24, 1802, 3141, 9.066, 1842, "s", "[Xe] 4f12 6s2", "Amplifies light signals in fibre-optic cables."],
  ["Tm", "Thulium", 168.93, 1.25, 1818, 2223, 9.321, 1879, "s", "[Xe] 4f13 6s2", "The rarest stable lanthanide; used in portable X-ray sources."],
  ["Yb", "Ytterbium", 173.05, null, 1097, 1469, 6.965, 1878, "s", "[Xe] 4f14 6s2", "Used in ultra-precise atomic clocks."],
  ["Lu", "Lutetium", 174.97, 1.27, 1925, 3675, 9.84, 1907, "s", "[Xe] 4f14 5d1 6s2", "The densest lanthanide; found in PET scan detectors."],
  ["Hf", "Hafnium", 178.49, 1.3, 2506, 4876, 13.31, 1923, "s", "[Xe] 4f14 5d2 6s2", "Control rods in nuclear submarines and chip insulators."],
  ["Ta", "Tantalum", 180.95, 1.5, 3290, 5731, 16.654, 1802, "s", "[Xe] 4f14 5d3 6s2", "Tiny capacitors in phones; safe inside the body."],
  ["W", "Tungsten", 183.84, 2.36, 3695, 5828, 19.25, 1783, "s", "[Xe] 4f14 5d4 6s2", "Has the highest melting point of any metal."],
  ["Re", "Rhenium", 186.21, 1.9, 3459, 5869, 21.02, 1925, "s", "[Xe] 4f14 5d5 6s2", "Found in jet engine superalloys; one of the rarest elements."],
  ["Os", "Osmium", 190.23, 2.2, 3306, 5285, 22.59, 1803, "s", "[Xe] 4f14 5d6 6s2", "The densest naturally occurring element."],
  ["Ir", "Iridium", 192.22, 2.20, 2719, 4701, 22.56, 1803, "s", "[Xe] 4f14 5d7 6s2", "Extremely corrosion resistant; enriched in the dinosaur-extinction layer."],
  ["Pt", "Platinum", 195.08, 2.28, 2041.4, 4098, 21.45, 1735, "s", "[Xe] 4f14 5d9 6s1", "A precious catalyst and jewellery metal."],
  ["Au", "Gold", 196.97, 2.54, 1337.33, 3129, 19.3, 0, "s", "[Xe] 4f14 5d10 6s1", "Prized for its beauty; it never tarnishes."],
  ["Hg", "Mercury", 200.59, 2.00, 234.32, 629.88, 13.534, 0, "l", "[Xe] 4f14 5d10 6s2", "The only metal that is liquid at room temperature."],
  ["Tl", "Thallium", 204.38, 1.62, 577, 1746, 11.85, 1861, "s", "[Xe] 4f14 5d10 6s2 6p1", "Highly toxic; once used as rat poison."],
  ["Pb", "Lead", 207.2, 2.33, 600.61, 2022, 11.34, 0, "s", "[Xe] 4f14 5d10 6s2 6p2", "Dense and soft; shields against radiation and fills car batteries."],
  ["Bi", "Bismuth", 208.98, 2.02, 544.4, 1837, 9.78, 1753, "s", "[Xe] 4f14 5d10 6s2 6p3", "Forms iridescent, stair-stepped crystals; barely radioactive."],
  ["Po", "Polonium", 209, 2.0, 527, 1235, 9.196, 1898, "s", "[Xe] 4f14 5d10 6s2 6p4", "Discovered by Marie Curie; intensely radioactive."],
  ["At", "Astatine", 210, 2.2, 575, 610, null, 1940, "s", "[Xe] 4f14 5d10 6s2 6p5", "The rarest naturally occurring element on Earth."],
  ["Rn", "Radon", 222, 2.2, 202, 211.3, 0.00973, 1900, "g", "[Xe] 4f14 5d10 6s2 6p6", "A radioactive gas that seeps from soil into basements."],
  ["Fr", "Francium", 223, 0.79, null, null, null, 1939, "s", "[Rn] 7s1", "So unstable that only a few dozen grams exist at any moment."],
  ["Ra", "Radium", 226, 0.9, 973, 2010, 5.5, 1898, "s", "[Rn] 7s2", "Glows faintly in the dark; once used in luminous paint."],
  ["Ac", "Actinium", 227, 1.1, 1323, 3471, 10.07, 1899, "s", "[Rn] 6d1 7s2", "Glows blue in the dark and names the actinide series."],
  ["Th", "Thorium", 232.04, 1.3, 2115, 5061, 11.72, 1829, "s", "[Rn] 6d2 7s2", "A potential nuclear fuel, more abundant than uranium."],
  ["Pa", "Protactinium", 231.04, 1.5, 1841, 4300, 15.37, 1913, "s", "[Rn] 5f2 6d1 7s2", "Rare, radioactive and toxic."],
  ["U", "Uranium", 238.03, 1.38, 1405.3, 4404, 19.1, 1789, "s", "[Rn] 5f3 6d1 7s2", "The fuel of nuclear power."],
  ["Np", "Neptunium", 237, 1.36, 917, 4273, 20.45, 1940, "s", "[Rn] 5f4 6d1 7s2", "The first transuranic element, named for Neptune."],
  ["Pu", "Plutonium", 244, 1.28, 912.5, 3501, 19.816, 1940, "s", "[Rn] 5f6 7s2", "Used in nuclear weapons and spacecraft power sources."],
  ["Am", "Americium", 243, 1.13, 1449, 2880, 12.0, 1944, "s", "[Rn] 5f7 7s2", "Sits inside household smoke detectors."],
  ["Cm", "Curium", 247, 1.28, 1613, 3383, 13.51, 1944, "s", "[Rn] 5f7 6d1 7s2", "Named for Marie and Pierre Curie."],
  ["Bk", "Berkelium", 247, 1.3, 1259, 2900, 14.78, 1949, "s", "[Rn] 5f9 7s2", "Named after Berkeley, California."],
  ["Cf", "Californium", 251, 1.3, 1173, 1743, 15.1, 1950, "s", "[Rn] 5f10 7s2", "An intense neutron source used to start nuclear reactors."],
  ["Es", "Einsteinium", 252, 1.3, 1133, null, 8.84, 1952, "s", "[Rn] 5f11 7s2", "Discovered in the debris of the first hydrogen bomb test."],
  ["Fm", "Fermium", 257, 1.3, 1800, null, null, 1952, "s", "[Rn] 5f12 7s2", "Named for Enrico Fermi."],
  ["Md", "Mendelevium", 258, 1.3, 1100, null, null, 1955, "s", "[Rn] 5f13 7s2", "Named for Dmitri Mendeleev, who devised the periodic table."],
  ["No", "Nobelium", 259, 1.3, 1100, null, null, 1958, "s", "[Rn] 5f14 7s2", "Named for Alfred Nobel."],
  ["Lr", "Lawrencium", 266, null, 1900, null, null, 1961, "s", "[Rn] 5f14 7s2 7p1", "The final actinide, named for Ernest Lawrence."],
  ["Rf", "Rutherfordium", 267, null, 2400, 5800, 17, 1964, "u", "[Rn] 5f14 6d2 7s2", "The first transactinide, made a few atoms at a time."],
  ["Db", "Dubnium", 268, null, null, null, null, 1968, "u", "[Rn] 5f14 6d3 7s2", "Named for Dubna, Russia."],
  ["Sg", "Seaborgium", 269, null, null, null, null, 1974, "u", "[Rn] 5f14 6d4 7s2", "Named for Glenn Seaborg, while he was still alive."],
  ["Bh", "Bohrium", 270, null, null, null, null, 1981, "u", "[Rn] 5f14 6d5 7s2", "Named for Niels Bohr."],
  ["Hs", "Hassium", 277, null, null, null, null, 1984, "u", "[Rn] 5f14 6d6 7s2", "Named for Hesse, Germany."],
  ["Mt", "Meitnerium", 278, null, null, null, null, 1982, "u", "[Rn] 5f14 6d7 7s2", "Named for physicist Lise Meitner."],
  ["Ds", "Darmstadtium", 281, null, null, null, null, 1994, "u", "[Rn] 5f14 6d8 7s2", "Named for Darmstadt, Germany."],
  ["Rg", "Roentgenium", 282, null, null, null, null, 1994, "u", "[Rn] 5f14 6d9 7s2", "Named for Wilhelm Röntgen, discoverer of X-rays."],
  ["Cn", "Copernicium", 285, null, null, null, null, 1996, "u", "[Rn] 5f14 6d10 7s2", "Named for Nicolaus Copernicus; probably quite volatile."],
  ["Nh", "Nihonium", 286, null, null, null, null, 2003, "u", "[Rn] 5f14 6d10 7s2 7p1", "The first element discovered in Asia, named for Japan."],
  ["Fl", "Flerovium", 289, null, null, null, null, 1998, "u", "[Rn] 5f14 6d10 7s2 7p2", "Named for the Flerov Laboratory in Dubna."],
  ["Mc", "Moscovium", 290, null, null, null, null, 2003, "u", "[Rn] 5f14 6d10 7s2 7p3", "Named for the Moscow region."],
  ["Lv", "Livermorium", 293, null, null, null, null, 2000, "u", "[Rn] 5f14 6d10 7s2 7p4", "Named for Lawrence Livermore National Laboratory."],
  ["Ts", "Tennessine", 294, null, null, null, null, 2010, "u", "[Rn] 5f14 6d10 7s2 7p5", "Named for Tennessee, home of Oak Ridge National Laboratory."],
  ["Og", "Oganesson", 294, null, null, null, null, 2002, "u", "[Rn] 5f14 6d10 7s2 7p6", "The heaviest known element, named for Yuri Oganessian."],
];

const CATEGORIES = {
  alkali:       { label: "Alkali metal",        color: "#FF9F0A" },
  alkaline:     { label: "Alkaline earth",      color: "#FFD60A" },
  transition:   { label: "Transition metal",    color: "#0A84FF" },
  post:         { label: "Post-transition",     color: "#40C8E0" },
  metalloid:    { label: "Metalloid",           color: "#30D158" },
  nonmetal:     { label: "Nonmetal",            color: "#BF5AF2" },
  halogen:      { label: "Halogen",             color: "#FF375F" },
  noble:        { label: "Noble gas",           color: "#5E5CE6" },
  lanthanide:   { label: "Lanthanide",          color: "#AC8E68" },
  actinide:     { label: "Actinide",            color: "#FF6482" },
};

const CORE_SHELLS = {
  He: [2], Ne: [2, 8], Ar: [2, 8, 8], Kr: [2, 8, 18, 8], Xe: [2, 8, 18, 18, 8], Rn: [2, 8, 18, 32, 18, 8],
};

const SETS = {
  alkali: [3, 11, 19, 37, 55, 87],
  alkaline: [4, 12, 20, 38, 56, 88],
  noble: [2, 10, 18, 36, 54, 86, 118],
  metalloid: [5, 14, 32, 33, 51, 52],
  halogen: [9, 17, 35, 53, 85, 117],
  nonmetal: [1, 6, 7, 8, 15, 16, 34],
  post: [13, 31, 49, 50, 81, 82, 83, 84, 113, 114, 115, 116],
};

function categoryOf(n) {
  for (const k in SETS) if (SETS[k].includes(n)) return k;
  if (n >= 57 && n <= 71) return "lanthanide";
  if (n >= 89 && n <= 103) return "actinide";
  return "transition";
}

// Grid position: rows 1-7 main table, 9-10 f-block rows.
function positionOf(n) {
  if (n === 1) return { row: 1, col: 1 };
  if (n === 2) return { row: 1, col: 18 };
  if (n <= 4) return { row: 2, col: n - 2 };
  if (n <= 10) return { row: 2, col: n + 8 };
  if (n <= 12) return { row: 3, col: n - 10 };
  if (n <= 18) return { row: 3, col: n };
  if (n <= 36) return { row: 4, col: n - 18 };
  if (n <= 54) return { row: 5, col: n - 36 };
  if (n <= 56) return { row: 6, col: n - 54 };
  if (n <= 71) return { row: 9, col: n - 54, f: true };
  if (n <= 86) return { row: 6, col: n - 68 };
  if (n <= 88) return { row: 7, col: n - 86 };
  if (n <= 103) return { row: 10, col: n - 86, f: true };
  return { row: 7, col: n - 100 };
}

function shellsOf(config) {
  const shells = [];
  for (const tok of config.split(" ")) {
    const core = tok.match(/^\[(\w+)\]$/);
    if (core) { shells.push(...CORE_SHELLS[core[1]]); continue; }
    const m = tok.match(/^(\d)([spdf])(\d+)$/);
    const i = +m[1] - 1;
    shells[i] = (shells[i] || 0) + +m[3];
  }
  return shells;
}

const ELEMENTS = RAW.map((r, i) => {
  const n = i + 1;
  const pos = positionOf(n);
  const group = pos.f ? null : pos.col;
  const period = pos.f ? (n <= 71 ? 6 : 7) : pos.row;
  let block = "d";
  if (pos.f) block = "f";
  else if (n === 2 || group <= 2) block = "s";
  else if (group >= 13) block = "p";
  return {
    n, sym: r[0], name: r[1], mass: r[2], en: r[3], melt: r[4], boil: r[5], density: r[6],
    year: r[7], phase: r[8], config: r[9], fact: r[10],
    cat: categoryOf(n), pos, group, period, block, shells: shellsOf(r[9]),
  };
});
