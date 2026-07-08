cd "$(dirname "$0")"/../

if [ -z "$1" ]; then
  swiftformat . --exclude Sources/ULID/*,Tests/ULIDTests/*
else
  swiftformat $1
fi