#!/usr/bin/env bash
# Genera il progetto Xcode e ri-applica le patch manuali.
# Uso: cd app && ./generate.sh
set -euo pipefail

PBXPROJ="Ascesa.xcodeproj/project.pbxproj"

echo "▶ xcodegen generate"
xcodegen generate

# ──────────────────────────────────────────────────────────────────────────────
# PATCH: XcodeGen 2.45.x non genera PBXResourcesBuildPhase per gli xcassets.
# Aggiunge manualmente file references, build files, build phases e li cablano
# nei target iOS e Watch.
# ──────────────────────────────────────────────────────────────────────────────

echo "▶ Applico patch PBXResourcesBuildPhase..."

python3 - "$PBXPROJ" <<'PYEOF'
import sys, re

path = sys.argv[1]
src  = open(path).read()

# Idempotente: esce se la patch è già applicata
if "AA11BB22CC33DD44EE55FF01" in src:
    print("  già applicata, skip.")
    sys.exit(0)

# 1. PBXBuildFile – due voci
old = "/* End PBXBuildFile section */"
new = (
    "\t\tAA11BB22CC33DD44EE55FF01 /* Assets.xcassets in Resources */ = "
    "{isa = PBXBuildFile; fileRef = AA11BB22CC33DD44EE55FF02 /* Assets.xcassets */; };\n"
    "\t\tAA11BB22CC33DD44EE55FF03 /* Assets.xcassets in Resources */ = "
    "{isa = PBXBuildFile; fileRef = AA11BB22CC33DD44EE55FF04 /* Assets.xcassets */; };\n"
    + old
)
assert old in src, "Marker PBXBuildFile non trovato"
src = src.replace(old, new, 1)

# 2. PBXFileReference – due voci
old = "/* End PBXFileReference section */"
new = (
    "\t\tAA11BB22CC33DD44EE55FF02 /* Assets.xcassets (iOS) */ = "
    "{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; "
    "name = Assets.xcassets; path = Resources/iOS/Assets.xcassets; sourceTree = SOURCE_ROOT; };\n"
    "\t\tAA11BB22CC33DD44EE55FF04 /* Assets.xcassets (Watch) */ = "
    "{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; "
    "name = Assets.xcassets; path = Resources/Watch/Assets.xcassets; sourceTree = SOURCE_ROOT; };\n"
    + old
)
assert old in src, "Marker PBXFileReference non trovato"
src = src.replace(old, new, 1)

# 3. PBXResourcesBuildPhase – sezione completa dopo Frameworks
old = "/* End PBXFrameworksBuildPhase section */"
resources_section = """
/* Begin PBXResourcesBuildPhase section */
\t\tAA11BB22CC33DD44EE55FF05 /* Resources */ = {
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\tAA11BB22CC33DD44EE55FF01 /* Assets.xcassets in Resources */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
\t\tAA11BB22CC33DD44EE55FF06 /* Resources */ = {
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\tAA11BB22CC33DD44EE55FF03 /* Assets.xcassets in Resources */,
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
/* End PBXResourcesBuildPhase section */
"""
new = old + resources_section
assert old in src, "Marker PBXFrameworksBuildPhase non trovato"
src = src.replace(old, new, 1)

# 4. Aggiungi file refs ai gruppi
# iOS xcassets → gruppo radice (EA7A7364F664F584D2F1B963)
src = re.sub(
    r'(EA7A7364F664F584D2F1B963\s*=\s*\{[^}]+children\s*=\s*\()',
    r'\1\n\t\t\t\tAA11BB22CC33DD44EE55FF02 /* Assets.xcassets (iOS) */,',
    src, count=1
)
# Watch xcassets → gruppo Watch (aggiunge dentro children prima della ) finale)
src = re.sub(
    r'(0411F0EC499A5181A19B6D6F\s*/\*\s*Watch\s*\*/[^{]*\{[^(]*children\s*=\s*\()(.*?)(\);)',
    lambda m: m.group(1) + m.group(2) + '\t\t\t\tAA11BB22CC33DD44EE55FF04 /* Assets.xcassets (Watch) */,\n\t\t\t' + m.group(3),
    src, count=1, flags=re.DOTALL
)

# 5. Cablare i build phase nei target
# Cerca l'array buildPhases del target Ascesa (ha Frameworks) e aggiunge Resources
src = re.sub(
    r'(buildPhases\s*=\s*\([^)]+/\*\s*Frameworks\s*\*/,)',
    r'\1\n\t\t\t\tAA11BB22CC33DD44EE55FF05 /* Resources */,',
    src, count=1
)
# Target Watch (ha solo Sources, no Frameworks)
src = re.sub(
    r'(buildPhases\s*=\s*\(\s*[A-F0-9]+\s*/\*\s*Sources\s*\*/,\s*\);)',
    lambda m: m.group(0).replace(
        ');',
        '\n\t\t\t\tAA11BB22CC33DD44EE55FF06 /* Resources */,\n\t\t\t);'
    ),
    src, count=1
)

open(path, 'w').write(src)
print("  patch applicata.")
PYEOF

echo "✅ Fatto. Riapri Ascesa.xcodeproj in Xcode."
