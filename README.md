# shin-freetown

A streamlined tool to convert GeoTIFF imagery from OpenAerialMap to lossy WebP PMTiles format. This project is a simplified version of [shin-abidjan](https://github.com/optgeo/shin-abidjan), using the `just` task runner as a homage to the mapterhorn project.

## Features

- Convert remote GeoTIFF to PMTiles using `/vsicurl` (no local download required)
- Generate lossy WebP format for efficient web delivery
- Preserve metadata including attribution and licensing information
- Simple task-based workflow using Justfile

## Prerequisites

- [just](https://github.com/casey/just) - Command runner
- [rio-pmtiles](https://github.com/developmentseed/rio-pmtiles) - Rasterio plugin for PMTiles generation
- GDAL with /vsicurl support (usually included with rasterio)

## Installation

1. Install `just`:
   ```bash
   # macOS
   brew install just
   
   # Linux
   cargo install just
   # or use your package manager
   ```

2. Install `rio-pmtiles`:
   ```bash
   pip install rio-pmtiles
   ```

## Usage

### Basic Usage

Convert the default Freetown imagery:

```bash
just go
```

### Advanced Configuration

All settings can be customized via environment variables:

```bash
# Custom source and output
SOURCE_URL="https://example.com/image.tif" \
OUTPUT_PATH="my_output.pmtiles" \
just go

# Full metadata customization
TITLE="My Image" \
ATTRIBUTION="My Organization (Jane Doe)" \
LICENSE="CC BY 4.0" \
DESCRIPTION="Custom description" \
just go
```

### Available Tasks

- `just` or `just --list` - Show all available tasks
- `just go` - Run the GeoTIFF to PMTiles conversion
- `just config` - Display current configuration
- `just clean` - Remove output files

## Default Dataset

By default, this tool processes aerial imagery of Freetown, Sierra Leone:

- **Source**: [OpenAerialMap](https://map.openaerialmap.org/#/68bed3070dea6f775adb9b06)
- **Title**: Freetown_Main_body
- **Uploaded by**: Ivan Gayton
- **Date**: 2025-04-16
- **Resolution**: 4cm
- **Provider**: HOT (Humanitarian OpenStreetMap Team)
- **Platform**: UAV
- **Sensor**: DJI Mini 4 Pro With DroneTM
- **Image Size**: 9.82GB
- **Type**: Image + Map Layer
- **License**: CC BY-SA 4.0
- **OIN ID**: 68bed3070dea6f775adb9b06

## Metadata Mapping

The following table shows how OpenAerialMap metadata maps to PMTiles metadata:

| OpenAerialMap Field | Environment Variable | PMTiles Field | Usage |
|---------------------|---------------------|---------------|-------|
| title | `TITLE` | `--title` | Main tile title |
| provider (uploaded by) | `ATTRIBUTION` | `--attribution` | "HOT (Ivan Gayton)" - Displayed in map attribution |
| license | `LICENSE` | `--pmtiles-metadata "license=..."` | "CC BY-SA 4.0" - Critical licensing information |
| date / resolution / platform / sensor | `DESCRIPTION` | `--description` | Combined technical details |
| id | `OIN_ID` | `--pmtiles-metadata "oin_id=..."` | OpenAerialMap reference (for advanced use) |

### Important Metadata Notes

- **Attribution**: Prominently displayed as "HOT (Ivan Gayton)" to credit the data provider and uploader
- **License**: The CC BY-SA 4.0 license is explicitly embedded in the PMTiles metadata - this is critical for legal compliance
- **OIN ID**: Stored as supplementary metadata for traceability but not prominently displayed
- **Description**: Contains technical details (resolution, date, platform, sensor) for reference

## Configuration Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SOURCE_URL` | Freetown imagery URL | Source GeoTIFF URL (accessed via /vsicurl) |
| `OUTPUT_PATH` | `freetown_main_body.pmtiles` | Output PMTiles file path |
| `TITLE` | `Freetown_Main_body` | Tileset title |
| `ATTRIBUTION` | `HOT (Ivan Gayton)` | Attribution text for map display |
| `LICENSE` | `CC BY-SA 4.0` | License identifier |
| `DESCRIPTION` | (Full technical details) | Detailed description of the imagery |
| `OIN_ID` | `68bed3070dea6f775adb9b06` | OpenAerialMap unique identifier |

## Technical Details

### Conversion Parameters

- **Encoding**: WebP (lossy compression)
- **Quality**: 75 (good balance of size and quality)
- **Resampling**: Bilinear
- **Alpha Channel**: Enabled (converts NODATA to transparent pixels)
- **Min Zoom**: 10
- **Max Zoom**: 22

### NODATA Handling

NODATA in aerial imagery can be expressed in several ways (explicit NODATA value, dataset mask, or pixels with RGB == 0). If NODATA is not handled explicitly, it commonly appears as black pixels in generated tiles. The recommended, tested workflow used in this repository is:

1. Inspect the source TIFF for NODATA or a dataset mask:

```bash
gdalinfo source.tif
```

2. If the dataset has a dataset mask (Mask Flags: PER_DATASET) or NODATA is unspecified but black pixels indicate background, create an explicit alpha band from the mask:

```bash
# create alpha from dataset mask
gdalwarp -dstalpha source.tif source_alpha.tif
```

3. If the image uses black RGB (0,0,0) pixels to indicate background, convert those pixels to fully transparent by setting alpha=0 where R=G=B=0. Example (uses the `rasterio` Python package available in the `shin-freetown` environment):

```bash
/Users/hfu/.local/share/mamba/envs/shin-freetown/bin/python - <<'PY'
import rasterio, numpy as np
src='source_alpha.tif'
dst='source_alpha_nodata.tif'
with rasterio.open(src) as s:
   profile=s.profile.copy()
   data=s.read()
R,G,B,A = data[0], data[1], data[2], data[3]
mask = (R==0)&(G==0)&(B==0)
A[mask]=0
with rasterio.open(dst, 'w', **profile) as d:
   d.write(np.vstack([R[np.newaxis],G[np.newaxis],B[np.newaxis],A[np.newaxis]]))
print('wrote', dst)
PY
```

4. Convert the prepared alpha-enabled TIFF to PMTiles using the `shin-freetown` recommended parameters (example):

```bash
export OMP_NUM_THREADS=1 GDAL_CACHEMAX=512
PATH=/Users/hfu/.local/share/mamba/envs/shin-freetown/bin:$PATH \
  rio pmtiles source_alpha_nodata.tif output.pmtiles \
   -j 1 --exclude-empty-tiles -f WEBP --tile-size 512 --resampling bilinear \
   --rgba --name "Title" --attribution "Attribution" \
   --description "Description" --zoom-levels 10..21 --co QUALITY=75
```

Notes and tips:
- If your TIFF already has a valid NODATA value, you can skip step 2/3 and use `--rgba` or `-a_nodata` to preserve transparency.
- The `gdalwarp -dstalpha` step adds an explicit alpha band (increasing file size) but makes transparency handling robust across downstream tools.
- For very large imagery, prefer testing the workflow on a small clip (see repository tests) before running the full conversion.

This repository contains helper `just` tasks (`download` and `convert`) that follow the workflow above. See the `Justfile` for defaults and environment-variable-driven configuration.

### Why /vsicurl?

The tool uses GDAL's `/vsicurl` virtual file system to access remote GeoTIFF files directly without downloading them first. This:
- Saves local disk space
- Reduces processing time
- Works seamlessly with rio-pmtiles

## License

This project (the conversion tool itself) is licensed under CC0 1.0 Universal. See [LICENSE](LICENSE) for details.

**Note**: The output data inherits the license of the source imagery. For the default Freetown dataset, the output is licensed under CC BY-SA 4.0 as specified in the source metadata.

## Related Projects

- [shin-abidjan](https://github.com/optgeo/shin-abidjan) - Previous version using Makefile and shell scripts
- [mapterhorn](https://github.com/felt/mapterhorn) - Inspiration for using just as task runner
- [rio-pmtiles](https://github.com/developmentseed/rio-pmtiles) - The core conversion tool