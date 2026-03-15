# immich-filename-sorting-exif-updater

A lightweight Docker container that rewrites EXIF timestamps so that [Immich](https://immich.app/) albums are sorted by filename instead of date.

## Problem

Immich does not support sorting albums by filename. The only available sort is by date (`DateTimeOriginal`). For collections where natural file order matters — scans, screenshots, numbered series — albums appear in the wrong order.

## Solution

This container takes a mounted folder, sorts files by name using [natural sort](https://en.wikipedia.org/wiki/Natural_sort_order) (`img2` before `img10`), and rewrites EXIF timestamps sequentially so Immich reflects the filename order.

- Rewrites `DateTimeOriginal`, `CreateDate`, and `ModifyDate` via [ExifTool](https://exiftool.org/)
- Works on images (JPG, PNG, HEIC, GIF) and videos (MP4, MOV)
- Creates EXIF dates on files that have none (PNG, screenshots...)
- Modifies files in-place — no copies
- Each directory gets its own independent sequence starting from `BASE_DATE`
- Runs on a cron schedule via [supercronic](https://github.com/aptible/supercronic)

## Usage

### One-time dry-run

```bash
docker run --rm \
  -v /path/to/photos:/data \
  -e CRON_EXPRESSION="0 0 31 2 *" \
  -e RUN_IMMEDIATELY=true \
  -e DRY_RUN=true \
  ghcr.io/raknam/immich-filename-sorting-exif-updater:main
```

### Scheduled execution (every hour)

```bash
docker run -d --name exif-updater \
  -v /path/to/photos:/data \
  -e CRON_EXPRESSION="0 * * * *" \
  -e RUN_IMMEDIATELY=true \
  ghcr.io/raknam/immich-filename-sorting-exif-updater:main
```

### Docker Compose

```yaml
services:
  exif-updater:
    image: ghcr.io/raknam/immich-filename-sorting-exif-updater:main
    volumes:
      - /nas/photos:/data
    environment:
      - CRON_EXPRESSION=0 * * * *
      - RUN_IMMEDIATELY=true
      - RECURSIVE=true
      - EXTENSIONS=jpg
```

## Environment Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `CRON_EXPRESSION` | **Yes** | — | Crontab expression for scheduling (e.g. `0 * * * *` for every hour) |
| `RUN_IMMEDIATELY` | No | `false` | Set to `true` to run once at container startup before the cron schedule takes over |
| `BASE_DATE` | No | `2000-01-01 00:00:00` | Starting timestamp for the first file in each directory |
| `INCREMENT_SECONDS` | No | `1` | Seconds between each file's timestamp |
| `RECURSIVE` | No | `true` | Process subdirectories recursively (each directory gets its own sequence) |
| `DRY_RUN` | No | `false` | Preview changes without modifying files |
| `EXTENSIONS` | No | `jpg,jpeg,png,gif,mp4,mov,heic` | Comma-separated list of file extensions to process |

## How it works

Given this folder structure:

```
/data/
  ArtistA/
    Album1/
      scan_01.jpg    → 2000:01:01 00:00:00
      scan_02.jpg    → 2000:01:01 00:00:01
      scan_10.jpg    → 2000:01:01 00:00:02
    Album2/
      page1.jpg      → 2000:01:01 00:00:00
      page2.jpg      → 2000:01:01 00:00:01
  ArtistB/
    Album1/
      img001.jpg     → 2000:01:01 00:00:00
      img002.jpg     → 2000:01:01 00:00:01
```

- Files are sorted using **natural sort** (`scan_2` before `scan_10`)
- Each directory's sequence **resets** to `BASE_DATE` independently
- Intermediate directories with no matching files are skipped

## Building locally

```bash
docker build -t immich-sort-fixer .
docker run --rm -v /path/to/photos:/data -e CRON_EXPRESSION="0 * * * *" -e RUN_IMMEDIATELY=true immich-sort-fixer
```
