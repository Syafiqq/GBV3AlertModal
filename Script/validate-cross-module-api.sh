#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "$0")/.." && pwd)"
source_root="$repository_root/Library/GBV3AlertModal/Sources"
validation_root="$(mktemp -d /tmp/gb-v3-cross-module.XXXXXX)"
cleanup() {
  case "$validation_root" in
    /tmp/gb-v3-cross-module.*) rm -rf "$validation_root" ;;
    *) printf 'Refusing to remove unexpected validation path: %s\n' "$validation_root" >&2 ;;
  esac
}
trap cleanup EXIT
export CLANG_MODULE_CACHE_PATH="$validation_root/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$validation_root/swift-module-cache"

mkdir -p \
  "$validation_root/Sources/GBV3AlertModalCore" \
  "$validation_root/Sources/GBV3AlertModalSwiftUI" \
  "$validation_root/Sources/GBV3AlertModalUIKit" \
  "$validation_root/Sources/GBV3AlertModalMigration"

cp -R "$source_root/GBV3AlertModalCore/." "$validation_root/Sources/GBV3AlertModalCore/"
cp -R "$source_root/GBV3AlertModal/SwiftUI/." "$validation_root/Sources/GBV3AlertModalSwiftUI/"
cp -R "$source_root/GBV3AlertModal/Components" "$validation_root/Sources/GBV3AlertModalUIKit/"
cp -R "$source_root/GBV3AlertModal/Extensions" "$validation_root/Sources/GBV3AlertModalUIKit/"
cp -R "$source_root/GBV3AlertModal/Support" "$validation_root/Sources/GBV3AlertModalUIKit/"
cp -R "$source_root/GBV3AlertModal/Executor" "$validation_root/Sources/GBV3AlertModalUIKit/"
cp "$source_root/GBV3AlertModal"/*.swift "$validation_root/Sources/GBV3AlertModalUIKit/"
cp -R "$source_root/GBV3AlertModal/Assets.xcassets" "$validation_root/Sources/GBV3AlertModalUIKit/"
cp -R "$source_root/GBV3AlertModal/Migration/." "$validation_root/Sources/GBV3AlertModalMigration/"

# Window installation combines SwiftUI content with UIKit lifecycle APIs, so it belongs to the
# integration target rather than either independently consumable backend.
mv \
  "$validation_root/Sources/GBV3AlertModalUIKit/Executor/WindowModalRenderer.swift" \
  "$validation_root/Sources/GBV3AlertModalMigration/WindowModalRenderer.swift"

prepend_imports() {
  local directory="$1"
  shift
  local imports="$*"
  while IFS= read -r file; do
    local staged="$file.cross-module"
    {
      for module in $imports; do
        printf 'import %s\n' "$module"
      done
      printf '\n'
      command cat "$file"
    } > "$staged"
    mv "$staged" "$file"
  done < <(find "$directory" -type f -name '*.swift' -print)
}

prepend_imports "$validation_root/Sources/GBV3AlertModalSwiftUI" GBV3AlertModalCore
prepend_imports "$validation_root/Sources/GBV3AlertModalUIKit" GBV3AlertModalCore
prepend_imports "$validation_root/Sources/GBV3AlertModalMigration" \
  GBV3AlertModalCore GBV3AlertModalSwiftUI GBV3AlertModalUIKit

cat > "$validation_root/Package.swift" <<'MANIFEST'
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GBV3AlertModalBoundaryValidation",
    platforms: [.iOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/SnapKit/SnapKit.git", from: "5.7.0"),
    ],
    targets: [
        .target(name: "GBV3AlertModalCore"),
        .target(
            name: "GBV3AlertModalSwiftUI",
            dependencies: ["GBV3AlertModalCore"]
        ),
        .target(
            name: "GBV3AlertModalUIKit",
            dependencies: [
                "GBV3AlertModalCore",
                .product(name: "SnapKit", package: "SnapKit"),
            ],
            resources: [.process("Assets.xcassets")]
        ),
        .target(
            name: "GBV3AlertModalMigration",
            dependencies: [
                "GBV3AlertModalCore",
                "GBV3AlertModalSwiftUI",
                "GBV3AlertModalUIKit",
            ]
        ),
    ]
)
MANIFEST

sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
scratch="$validation_root/.build"
for target in \
  GBV3AlertModalCore \
  GBV3AlertModalSwiftUI \
  GBV3AlertModalUIKit \
  GBV3AlertModalMigration
do
  swift build \
    --package-path "$validation_root" \
    --scratch-path "$scratch" \
    --sdk "$sdk" \
    --triple arm64-apple-ios15.0-simulator \
    --target "$target"
done

printf 'Cross-module API validation succeeded.\n'
