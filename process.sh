#!/bin/sh
set -e

BASE_DATE="${BASE_DATE:-2000-01-01 00:00:00}"
INCREMENT_SECONDS="${INCREMENT_SECONDS:-1}"
RECURSIVE="${RECURSIVE:-true}"
DRY_RUN="${DRY_RUN:-false}"
EXTENSIONS="${EXTENSIONS:-jpg,jpeg,png,gif,mp4,mov,heic}"
DATA_DIR="/data"

# Build a case-insensitive regex pattern from EXTENSIONS for grep
build_ext_regex() {
  regex=""
  IFS=','
  for ext in $EXTENSIONS; do
    ext=$(echo "$ext" | tr -d ' ')
    if [ -n "$regex" ]; then
      regex="$regex|"
    fi
    regex="$regex${ext}"
  done
  unset IFS
  echo "\\.(${regex})$"
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

  ext_regex=$(build_ext_regex)

  # Find files in this directory only (maxdepth 1), filter by extension, sort naturally
  file_list=$(find "$dir" -maxdepth 1 -type f 2>/dev/null | grep -iE "$ext_regex" | sort -V)

  if [ -z "$file_list" ]; then
    echo "  (no matching files)"
    return
  fi

  current_epoch=$(date_to_epoch "$BASE_DATE")
  if [ -z "$current_epoch" ]; then
    echo "ERROR: invalid BASE_DATE '$BASE_DATE'" >&2
    exit 1
  fi

  # Read all current DateTimeOriginal values in one exiftool call (tab-separated: FileName\tDateTimeOriginal)
  dto_map=$(mktemp)
  exiftool -T -FileName -DateTimeOriginal "$dir" 2>/dev/null > "$dto_map"

  stats_file=$(mktemp)
  echo "0 0" > "$stats_file"

  echo "$file_list" | while IFS= read -r filepath; do
    filename=$(basename "$filepath")
    exif_ts=$(epoch_to_exif "$current_epoch")

    # Exact filename match in dto_map (field 1 = filename, field 2 = DateTimeOriginal)
    current_dto=$(awk -F'\t' -v fn="$filename" '$1 == fn { print $2 }' "$dto_map")

    if [ "$current_dto" = "$exif_ts" ]; then
      read updated skipped < "$stats_file"
      echo "$updated $((skipped + 1))" > "$stats_file"
      current_epoch=$((current_epoch + INCREMENT_SECONDS))
      continue
    fi

    if [ "$DRY_RUN" = "true" ]; then
      echo "  [DRY-RUN] $filename -> $exif_ts (was: ${current_dto:-none})"
    else
      exiftool -overwrite_original \
        -DateTimeOriginal="$exif_ts" \
        -CreateDate="$exif_ts" \
        -ModifyDate="$exif_ts" \
        "$filepath" > /dev/null 2>&1
      echo "  $filename -> $exif_ts"
    fi

    read updated skipped < "$stats_file"
    echo "$((updated + 1)) $skipped" > "$stats_file"
    current_epoch=$((current_epoch + INCREMENT_SECONDS))
  done

  read updated skipped < "$stats_file"
  rm -f "$stats_file" "$dto_map"
  echo "  (updated: $updated, skipped: $skipped)"
}

# Depth-first traversal: process current dir, then recurse into subdirs one at a time
process_tree() {
  process_directory "$1"
  if [ "$RECURSIVE" = "true" ]; then
    find "$1" -mindepth 1 -maxdepth 1 -type d | sort -V | while IFS= read -r subdir; do
      process_tree "$subdir"
    done
  fi
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

process_tree "$DATA_DIR"

echo ""
echo "=== Done ==="
