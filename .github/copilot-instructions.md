# Copilot Instructions for shin-freetown

## Project Overview

shin-freetown is a streamlined GeoTIFF to PMTiles converter, specifically designed to process aerial imagery from OpenAerialMap. It simplifies the shin-abidjan approach by consolidating all conversion logic into a single Justfile.

## Key Design Principles

### 1. Just Task Runner
- All tasks are defined in a single `Justfile` (not split across Makefile + scripts)
- Uses `just` as a homage to the mapterhorn project
- Task definitions include embedded bash scripts for complex operations

### 2. Environment Variable Configuration
- All configurable parameters use environment variables with sensible defaults
- Variables include: `SOURCE_URL`, `OUTPUT_PATH`, `TITLE`, `ATTRIBUTION`, `LICENSE`, `DESCRIPTION`, `OIN_ID`
- Use `env_var_or_default()` in Justfile for default values

### 3. Remote File Access
- Uses GDAL's `/vsicurl` virtual filesystem to access remote GeoTIFF files
- No local download required - streaming access only
- Critical for working with large (9.82GB+) imagery files

### 4. Metadata Handling
- OpenAerialMap metadata cannot be automatically retrieved
- All metadata configured via environment variables
- Metadata mapping:
  - `TITLE` → rio pmtiles `--title`
  - `ATTRIBUTION` → rio pmtiles `--attribution` (format: "HOT (Ivan Gayton)")
  - `LICENSE` → rio pmtiles `--pmtiles-metadata "license=..."`
  - `DESCRIPTION` → rio pmtiles `--description` (technical details)
  - `OIN_ID` → rio pmtiles `--pmtiles-metadata "oin_id=..."` (less prominent)

## Technical Implementation

### Rio PMTiles Command Structure
```bash
rio pmtiles \
    "/vsicurl/SOURCE_URL" \
    "OUTPUT_PATH" \
    --encoding webp \
    --resampling bilinear \
    --add-alpha \
    --title "TITLE" \
    --attribution "ATTRIBUTION" \
    --description "DESCRIPTION" \
    --minzoom 10 \
    --maxzoom 22 \
    --pmtiles-metadata "license=LICENSE" \
    --pmtiles-metadata "oin_id=OIN_ID" \
    --co QUALITY=75
```

### Key Parameters
- **Encoding**: WebP for efficient lossy compression
- **Quality**: 75 (balance between size and quality)
- **Zoom levels**: 10-22 (appropriate for 4cm resolution)
- **Alpha channel**: Enabled (--add-alpha) to convert NODATA pixels to transparent pixels
- **NODATA handling**: Prevents black NODATA blocks by using transparency

## Default Dataset (Freetown)

- **URL**: https://oin-hotosm-temp.s3.us-east-1.amazonaws.com/68bed3070dea6f775adb9b06/0/68bed3070dea6f775adb9b07.tif
- **Title**: Freetown_Main_body
- **Attribution**: HOT (Ivan Gayton)
- **License**: CC BY-SA 4.0 (must be prominently preserved)
- **Resolution**: 4cm
- **Date**: 2025-04-16
- **Size**: 9.82GB
- **OIN ID**: 68bed3070dea6f775adb9b06

## Important Considerations

### License Compliance
- The CC BY-SA 4.0 license MUST be explicitly embedded in PMTiles metadata
- Attribution should be prominently displayed: "HOT (Ivan Gayton)"
- These are legal requirements, not optional

### File Organization
- Single Justfile contains all logic (no separate scripts folder)
- .gitignore excludes: tmp/, *.pmtiles, build artifacts
- All documentation in English only

### Error Handling
- Use `set -euo pipefail` in bash scripts within Justfile
- Provide clear echo messages for progress tracking
- Create tmp directory if it doesn't exist

## Available Tasks

1. **default**: Show help (list all tasks)
2. **go**: Main conversion task
3. **config**: Display current configuration
4. **clean**: Remove temporary files
5. **clean-all**: Remove temporary files and output

## When Modifying

- Keep all logic in Justfile (don't create separate scripts)
- Maintain environment variable configurability
- Preserve metadata mapping documentation in README.md
- Ensure all text is in English
- Never remove license information from outputs
