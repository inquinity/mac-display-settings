#!/usr/bin/env bash
# shellcheck disable=SC2034  # Standard color palette; not every color is used.
#
# Build and sign the Display Settings Menu prototype without an Xcode project.
#
# Produces build/Display Settings Menu.app, which carries the Finder Sync
# extension in Contents/PlugIns. Only files under build/ are written.

set -euo pipefail

# Define color codes for terminal output
COLOR_GREEN="\e[32m"         # Used for success messages and instructions
COLOR_RED="\e[31m"           # Used for error messages and warnings
COLOR_YELLOW="\e[33m"        # Used for help text, lists, and informational content
COLOR_MAGENTA="\e[35m"       # Available for general use
COLOR_CYAN="\e[36m"          # Available for general use
COLOR_BLUE="\e[34m"          # Available for general use; does not show on screen well
COLOR_BRIGHTYELLOW="\e[93m"  # Used for highlighting important actions and status
COLOR_RESET="\e[0m"          # Used to reset color formatting

# Function to print colored output
print_colored() {
    local color="$1"
    local message="$2"
    printf '%b%s%b\n' "$color" "$message" "$COLOR_RESET"
}

# --- Globals ---------------------------------------------------------------

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
build_dir="$project_dir/build"
app_name="Display Settings Menu"
app_executable="DisplaySettingsMenu"
extension_name="DisplaySettingsMenuExtension"
minimum_macos="14.0"
signing_identity=""

# --- Helpers ---------------------------------------------------------------

usage() {
    print_colored "$COLOR_YELLOW" "Usage: ./build.sh [--identity <name-or-hash>]

Builds and signs build/$app_name.app with its Finder Sync extension.

Options:
  -i, --identity   Code signing identity. Defaults to the first
                   'Apple Development' or 'Mac Developer' identity in the
                   keychain, or ad-hoc signing ('-') if none is found.
  -h, --help       Show this help."
}

die() {
    print_colored "$COLOR_RED" "Error: $1" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "'$1' not found. Install the Xcode command line tools."
}

# Print the SHA-1 of the first development signing identity, if any.
# Using the hash avoids ambiguity when several certificates share a name.
find_development_identity() {
    security find-identity -v -p codesigning 2>/dev/null \
        | awk '/"(Apple Development|Mac Developer):/ { print $2; exit }'
}

# Compile Swift sources into a single executable.
# Arguments: output path, then extra swiftc flags, then "--", then sources.
compile_swift() {
    local output_path="$1"
    shift
    local extra_flags=()
    while [[ $# -gt 0 && "$1" != "--" ]]; do
        extra_flags+=("$1")
        shift
    done
    [[ $# -gt 0 ]] || die "compile_swift: missing '--' before sources."
    shift

    # The ${var+...} form keeps an empty array safe under set -u in bash 3.2,
    # which is what /usr/bin/env bash finds on a stock Mac.
    xcrun swiftc \
        -O \
        -target "$(uname -m)-apple-macos$minimum_macos" \
        -sdk "$(xcrun --show-sdk-path --sdk macosx)" \
        ${extra_flags[@]+"${extra_flags[@]}"} \
        -o "$output_path" \
        "$@"
}

# --- Argument parsing ------------------------------------------------------

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--identity)
            [[ $# -ge 2 ]] || die "--identity needs a value."
            signing_identity="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage
            die "Unknown option: $1"
            ;;
    esac
done

# --- Validation ------------------------------------------------------------

require_command xcrun
require_command codesign
require_command security

if [[ -z "$signing_identity" ]]; then
    signing_identity="$(find_development_identity)"
    if [[ -z "$signing_identity" ]]; then
        print_colored "$COLOR_RED" "Warning: no development identity found; signing ad-hoc. Finder may refuse to load the extension."
        signing_identity="-"
    fi
fi

# --- Main ------------------------------------------------------------------

app_bundle="$build_dir/$app_name.app"
extension_bundle="$app_bundle/Contents/PlugIns/$extension_name.appex"

print_colored "$COLOR_BRIGHTYELLOW" "Building $app_bundle"
rm -rf "$app_bundle"
mkdir -p "$app_bundle/Contents/MacOS" "$extension_bundle/Contents/MacOS"

cp "$project_dir/Resources/HostApp-Info.plist" "$app_bundle/Contents/Info.plist"
cp "$project_dir/Resources/FinderExtension-Info.plist" "$extension_bundle/Contents/Info.plist"

print_colored "$COLOR_YELLOW" "Compiling host app"
compile_swift "$app_bundle/Contents/MacOS/$app_executable" \
    -module-name "$app_executable" \
    -- "$project_dir"/Sources/HostApp/*.swift

# App extensions have no main(); NSExtensionMain from Foundation starts
# the extension and instantiates NSExtensionPrincipalClass.
print_colored "$COLOR_YELLOW" "Compiling Finder Sync extension"
compile_swift "$extension_bundle/Contents/MacOS/$extension_name" \
    -module-name "$extension_name" \
    -parse-as-library \
    -application-extension \
    -Xlinker -e -Xlinker _NSExtensionMain \
    -- "$project_dir"/Sources/FinderExtension/*.swift

# Sign inside-out: the extension first, then the app that contains it.
print_colored "$COLOR_YELLOW" "Signing with identity: $signing_identity"
codesign --force --timestamp=none --sign "$signing_identity" \
    --entitlements "$project_dir/Resources/FinderExtension.entitlements" \
    "$extension_bundle"
codesign --force --timestamp=none --sign "$signing_identity" "$app_bundle"
codesign --verify --deep --strict "$app_bundle"

print_colored "$COLOR_GREEN" "Built and signed: $app_bundle"
print_colored "$COLOR_GREEN" "Next: see README.md, section 'Try it'."
