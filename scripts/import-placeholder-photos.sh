#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
IMAGES_DIR="$ROOT_DIR/ENVI/Resources/Images"

if ! xcrun simctl list devices | grep -q "Booted"; then
  echo "❌ No booted simulator found. Boot a simulator first." >&2
  exit 1
fi

typeset -a media_files=(
  "$IMAGES_DIR/Closer.jpg"
  "$IMAGES_DIR/chopsticks.jpg"
  "$IMAGES_DIR/culture-food.jpg"
  "$IMAGES_DIR/cyclist.jpg"
  "$IMAGES_DIR/desert-car.jpg"
  "$IMAGES_DIR/fashion-group.jpg"
  "$IMAGES_DIR/fire-stunt.jpg"
  "$IMAGES_DIR/industrial-girl.jpg"
  "$IMAGES_DIR/jacket.jpg"
  "$IMAGES_DIR/office-girl.jpg"
  "$IMAGES_DIR/parking-garage.jpg"
  "$IMAGES_DIR/red-silhouette.jpg"
  "$IMAGES_DIR/runway.jpg"
  "$IMAGES_DIR/studio-fashion.jpg"
  "$IMAGES_DIR/subway.jpg"
  "$IMAGES_DIR/suit-phone.jpg"
  "$IMAGES_DIR/tennis.jpg"
)

for file in "${media_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "❌ Missing placeholder image: $file" >&2
    exit 1
  fi
done

xcrun simctl addmedia booted "${media_files[@]}"

echo "Imported ${#media_files[@]} placeholder images into the booted simulator photo library."
