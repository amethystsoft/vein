cd "$(dirname "$0")"/../ || exit 1

./Scripts/format.sh
swiftlint lint --quiet