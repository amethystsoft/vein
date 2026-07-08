cd "$(dirname "$0")"/../ || exit 1

if [ -z "$1" ]; then
  swiftformat . --exclude Sources/ULID/*,Tests/ULIDTests/*,Sources/VeinCore/VeinCore.docc/*,Sources/VeinSwiftUI/VeinSwiftUI.docc/*
else
  swiftformat $1
fi