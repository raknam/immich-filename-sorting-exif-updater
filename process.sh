#!/bin/sh
set -e

BASE_DATE="${BASE_DATE:-2000-01-01 00:00:00}"
INCREMENT_SECONDS="${INCREMENT_SECONDS:-1}"
RECURSIVE="${RECURSIVE:-false}"
DRY_RUN="${DRY_RUN:-false}"
EXTENSIONS="${EXTENSIONS:-jpg,jpeg,png,gif,mp4,mov,heic}"
DATA_DIR="/data"

# Build find -name filter from EXTENSIONS
build_name_filter() {
  filter=""
  IFS=','
  for ext in $EXTENSIONS; do
    ext=$(echo "$ext" | tr -d ' ')
    if [ -n "$filter" ]; then
      filter="$filter -o"
    fi
    filter="$filter -iname *.${ext}"
  done
  unset IFS
  echo "$filter"
}

# Convert "YYYY-MM-DD HH:MM:SS" to epoch seconds
date_to_epoch() {
  date -d "$1" +%s 2>/dev/null
}

# Convert epoch seconds to "YYYY:MM:DD HH:MM:SS" (EXIF format)
epoch_to_exif() {
  date -d "@$1" '+%Y:%m:%d %H:%M:%S' 2>/dev/null
}

# Process a single directory: sort files by name (natural sort), assign sequential timestamps
process_directory() {
  dir="$1"
  echo "--- Processing directory: ${dir} ---"

  name_filter=$(build_name_filter)

  # Find files in this directory only (maxdepth 1), sort naturally by filename
  file_list=$(eval "find \"$dir\" -maxdepth 1 -type f \( $name_filter \)" 2>/dev/null | sort -V)

  if [ -z "$file_list" ]; then
    echo "  (no matching files)"
    return
  fi

  current_epoch=$(date_to_epoch "$BASE_DATE")
  if [ -z "$current_epoch" ]; then
    echo "ERROR: invalid BASE_DATE '$BASE_DATE'" >&2
    exit 1
  fi

  echo "$file_list" | while IFS= read -r filepath; do
    filename=$(basename "$filepath")
    exif_ts=$(epoch_to_exif "$current_epoch")

    if [ "$DRY_RUN" = "true" ]; then
      echo "  [DRY-RUN] $filename -> $exif_ts"
    else
      exiftool -overwrite_original \
        -DateTimeOriginal="$exif_ts" \
        -CreateDate="$exif_ts" \
        -ModifyDate="$exif_ts" \
        "$filepath" > /dev/null 2>&1
      echo "  $filename -> $exif_ts"
    fi

    current_epoch=$((current_epoch + INCREMENT_SECONDS))
  done
}

# --- Main ---
echo "=== immich-filename-exif-updater === $(date '+%Y-%m-%d %H:%M:%S')"
echo "BASE_DATE:          $BASE_DATE"
echo "INCREMENT_SECONDS:  $INCREMENT_SECONDS"
echo "RECURSIVE:          $RECURSIVE"
echo "DRY_RUN:            $DRY_RUN"
echo "EXTENSIONS:         $EXTENSIONS"
echo ""

if [ ! -d "$DATA_DIR" ]; then
  echo "ERROR: $DATA_DIR is not mounted or not a directory" >&2
  exit 1
fi

if [ "$RECURSIVE" = "true" ]; then
  # Process each subdirectory independently (each gets its own sequence starting at BASE_DATE)
  # Process root directory first, then subdirectories in sorted order
  process_directory "$DATA_DIR"
  find "$DATA_DIR" -mindepth 1 -type d | sort -V | while IFS= read -r subdir; do
    process_directory "$subdir"
  done
else
  process_directory "$DATA_DIR"
fi

echo ""
echo "=== Done ==="
