#!/usr/bin/env python3
"""Transform SceneType.swift from switch-based to descriptor-based registry."""
import re
import sys

filepath = 'Ennui/SceneType.swift'
with open(filepath, 'r') as f:
    content = f.read()

# 1. Extract enum cases in declaration order
cases = re.findall(r'^\s*case (\w+) = "(\w+)"', content, re.MULTILINE)
case_set = {c[0] for c in cases}

# 2. Parse simple "case .X: return ..." properties
def extract_section(text, start_prop, end_prop):
    s = text.find(f'var {start_prop}')
    e = text.find(f'var {end_prop}') if end_prop else len(text)
    return text[s:e] if s != -1 else ""

def parse_string_returns(section):
    return dict(re.findall(r'case \.(\w+): return "([^"]*)"', section))

# displayName
display_names = parse_string_returns(extract_section(content, 'displayName', 'accessibilityDescription'))
# accessibilityDescription
accessibility = parse_string_returns(extract_section(content, 'accessibilityDescription', 'tapHint'))
# tapHint
tap_hints = parse_string_returns(extract_section(content, 'tapHint', 'icon'))
# icon
icons = parse_string_returns(extract_section(content, 'icon', 'tint'))
# tint (Color values)
tint_section = extract_section(content, 'tint', 'audioMood')
tints = dict(re.findall(r'case \.(\w+): return (Color\(red: [\d.]+, green: [\d.]+, blue: [\d.]+\))', tint_section))

# audioMood - grouped cases need special parsing
mood_section = extract_section(content, 'audioMood', None)
mood_map = {}
current_cases = []
for line in mood_section.split('\n'):
    refs = [r for r in re.findall(r'\.(\w+)', line) if r in case_set]
    current_cases.extend(refs)
    ret = re.search(r'return "(\w+)"', line)
    if ret:
        mood = ret.group(1)
        for c in current_cases:
            mood_map[c] = mood
        current_cases = []

# hasSceneKitVersion
sk_section = extract_section(content, 'hasSceneKitVersion', 'displayName')
scenekit_cases = set()
for m in re.finditer(r'\.(\w+)', sk_section):
    name = m.group(1)
    if name in case_set:
        scenekit_cases.add(name)

# 3. Fix remaining generic 3D icons
icon_overrides = {
    'medievalVillage3D': 'house.lodge.fill',
    'lateNightRerun3D': 'tv.fill',
    'jeonjuNight3D': 'moon.fill',
    'lastAndFirstMen3D': 'infinity',
}
for name, icon in icon_overrides.items():
    icons[name] = icon

# 4. Verify completeness
missing = []
for name, _ in cases:
    for prop, data in [('displayName', display_names), ('accessibility', accessibility),
                       ('tapHint', tap_hints), ('icon', icons), ('tint', tints),
                       ('audioMood', mood_map)]:
        if name not in data:
            missing.append(f"{name}.{prop}")
if missing:
    print(f"WARNING: Missing entries: {missing}", file=sys.stderr)
    sys.exit(1)

# 5. Generate the new file
lines = []
lines.append('import SwiftUI')
lines.append('')
lines.append('// MARK: - Scene Descriptor')
lines.append('')
lines.append('/// Co-located metadata for a single scene.  Adding a new scene means adding')
lines.append('/// one entry to ``SceneKind/descriptors`` instead of touching 7+ switch statements.')
lines.append('struct SceneDescriptor {')
lines.append('    let displayName: String')
lines.append('    let accessibilityDescription: String')
lines.append('    let tapHint: String')
lines.append('    let icon: String')
lines.append('    let tint: Color')
lines.append('    let audioMood: String')
lines.append('    let hasSceneKitVersion: Bool')
lines.append('')
lines.append('    init(')
lines.append('        displayName: String,')
lines.append('        accessibilityDescription: String,')
lines.append('        tapHint: String,')
lines.append('        icon: String,')
lines.append('        tint: Color,')
lines.append('        audioMood: String,')
lines.append('        hasSceneKitVersion: Bool = false')
lines.append('    ) {')
lines.append('        self.displayName = displayName')
lines.append('        self.accessibilityDescription = accessibilityDescription')
lines.append('        self.tapHint = tapHint')
lines.append('        self.icon = icon')
lines.append('        self.tint = tint')
lines.append('        self.audioMood = audioMood')
lines.append('        self.hasSceneKitVersion = hasSceneKitVersion')
lines.append('    }')
lines.append('}')
lines.append('')
lines.append('// MARK: - Scene Kind')
lines.append('')
lines.append('enum SceneKind: String, CaseIterable, Identifiable {')

# Enum cases
for name, raw in cases:
    lines.append(f'    case {name} = "{raw}"')

lines.append('')
lines.append('    var id: String { rawValue }')
lines.append('')
lines.append('    // MARK: - Descriptor Registry')
lines.append('')
lines.append('    /// Single source of truth for all scene metadata.')
lines.append('    private static let descriptors: [SceneKind: SceneDescriptor] = [')

for name, _ in cases:
    dn = display_names[name]
    ad = accessibility[name]
    th = tap_hints[name]
    ic = icons[name]
    ti = tints[name]
    am = mood_map[name]
    sk = name in scenekit_cases

    lines.append(f'        .{name}: SceneDescriptor(')
    lines.append(f'            displayName: "{dn}",')
    lines.append(f'            accessibilityDescription: "{ad}",')
    lines.append(f'            tapHint: "{th}",')
    lines.append(f'            icon: "{ic}",')
    lines.append(f'            tint: {ti},')
    if sk:
        lines.append(f'            audioMood: "{am}",')
        lines.append(f'            hasSceneKitVersion: true')
    else:
        lines.append(f'            audioMood: "{am}"')
    lines.append(f'        ),')

lines.append('    ]')
lines.append('')
lines.append('    // MARK: - Computed Properties')
lines.append('')
lines.append('    private var descriptor: SceneDescriptor {')
lines.append('        guard let d = Self.descriptors[self] else {')
lines.append('            fatalError("Missing descriptor for \\(self.rawValue)")')
lines.append('        }')
lines.append('        return d')
lines.append('    }')
lines.append('')
lines.append('    var hasSceneKitVersion: Bool { descriptor.hasSceneKitVersion }')
lines.append('    var displayName: String { descriptor.displayName }')
lines.append('    var accessibilityDescription: String { descriptor.accessibilityDescription }')
lines.append('    var tapHint: String { descriptor.tapHint }')
lines.append('    var icon: String { descriptor.icon }')
lines.append('    var tint: Color { descriptor.tint }')
lines.append('    var audioMood: String { descriptor.audioMood }')
lines.append('}')
lines.append('')

with open(filepath, 'w') as f:
    f.write('\n'.join(lines))

print(f"Wrote {len(lines)} lines to {filepath}")
print(f"Processed {len(cases)} scene cases")
print(f"SceneKit versions: {sorted(scenekit_cases)}")
print(f"Audio moods: {sorted(set(mood_map.values()))}")
