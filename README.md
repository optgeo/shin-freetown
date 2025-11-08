# shin-freetown

A streamlined tool to convert GeoTIFF imagery from OpenAerialMap to lossy WebP PMTiles format. This project is a simplified version of [shin-abidjan](https://github.com/optgeo/shin-abidjan), using the `just` task runner as a homage to the mapterhorn project.

## Features

- Convert remote GeoTIFF to PMTiles using `/vsicurl` (no local download required)
- Generate lossy WebP format for efficient web delivery
- Preserve metadata including attribution and licensing information
- Configurable temporary directory for systems with limited storage
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

# Custom temporary directory (useful for limited storage)
TMP_DIR="/mnt/large-disk/tmp" just go

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
- `just clean` - Remove temporary files
- `just clean-all` - Remove temporary files and output

## Default Dataset

By default, this tool processes aerial imagery of Freetown, Sierra Leone:

- **Source**: [OpenAerialMap](https://map.openaerialmap.org/#/68beefef128fd7aac0cd73ec)
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
- **OIN ID**: 68beefef128fd7aac0cd73ec

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
| `TMP_DIR` | `./tmp` | Temporary directory for processing |
| `TITLE` | `Freetown_Main_body` | Tileset title |
| `ATTRIBUTION` | `HOT (Ivan Gayton)` | Attribution text for map display |
| `LICENSE` | `CC BY-SA 4.0` | License identifier |
| `DESCRIPTION` | (Full technical details) | Detailed description of the imagery |
| `OIN_ID` | `68beefef128fd7aac0cd73ec` | OpenAerialMap unique identifier |

## Technical Details

### Conversion Parameters

- **Encoding**: WebP (lossy compression)
- **Quality**: 75 (good balance of size and quality)
- **Resampling**: Bilinear
- **Min Zoom**: 10
- **Max Zoom**: 22
- **Lossless**: Disabled (for smaller file sizes)

### Why /vsicurl?

The tool uses GDAL's `/vsicurl` virtual file system to access remote GeoTIFF files directly without downloading them first. This:
- Saves local disk space
- Reduces processing time
- Works seamlessly with rio-pmtiles

### Storage Considerations

For systems with limited storage, set `TMP_DIR` to a location with more space:

```bash
TMP_DIR="/mnt/external-drive/tmp" just go
```

## License

This project (the conversion tool itself) is licensed under CC0 1.0 Universal. See [LICENSE](LICENSE) for details.

**Note**: The output data inherits the license of the source imagery. For the default Freetown dataset, the output is licensed under CC BY-SA 4.0 as specified in the source metadata.

## Related Projects

- [shin-abidjan](https://github.com/optgeo/shin-abidjan) - Previous version using Makefile and shell scripts
- [mapterhorn](https://github.com/felt/mapterhorn) - Inspiration for using just as task runner
- [rio-pmtiles](https://github.com/developmentseed/rio-pmtiles) - The core conversion tool