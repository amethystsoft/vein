#!/bin/bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$REPO_ROOT/../VeinDocs"

cd "$REPO_ROOT"

echo "Clearing old output..."
rm -rf "$OUTPUT_DIR"

echo "selecting swift 6.3.3"
swiftly use 6.3.3 --global-default

echo "Compiling Unified DocC Archive..."
# Das Plugin generiert automatisch ein kombiniertes Archiv für alle deine Targets
swift package \
  --allow-writing-to-directory "$OUTPUT_DIR" \
  generate-documentation \
  --target VeinCore \
  --target VeinSwiftUI \
  --target Vein \
  --target VeinSCUI \
  --target ULID \
  --enable-experimental-combined-documentation \
  --output-path "$OUTPUT_DIR" \
  --transform-for-static-hosting

echo "Documentation generated at: $OUTPUT_DIR"

echo "re-selecting swift 6.4.1"
swiftly use 6.4.1 --global-default

echo "Replacing root index.html with a custom documentation hub..."

cp "$REPO_ROOT/docs/index.html" "$OUTPUT_DIR/index.html"

echo "Done! Custom dashboard successfully written to $OUTPUT_DIR/index.html"
