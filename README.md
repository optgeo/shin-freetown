# shin-freetown

A streamlined tool to convert GeoTIFF elevation data to Terrarium-encoded PMTiles for terrain visualization. This project follows the [mapterhorn](https://github.com/mapterhorn/mapterhorn) methodology for terrain tile generation.

## Overview

shin-freetown implements a 2-stage pipeline for processing elevation data:

1. **Stage 1: Bounds Generation** - Extract bounding box information (EPSG:3857) and metadata from source GeoTIFFs
2. **Stage 2: Tile Processing** - Cut elevation data into 512×512 tiles, apply Terrarium encoding, save as lossless WebP, and bundle into PMTiles

## Features

- **Terrarium RGB Encoding**: Industry-standard encoding for terrain visualization
  - Elevation formula: `elevation = (R × 256 + G + B / 256) - 32768`
  - Supports elevation range: -32,768m to +32,768m
  - Zoom-dependent vertical resolution (3.9mm at z19, 2048m at z0)
  
- **Lossless WebP Tiles**: Efficient storage with perfect reproduction of elevation data

- **EPSG:3857 (Web Mercator)**: Standard coordinate system for web mapping

- **Simple Task-Based Workflow**: Uses `just` task runner following mapterhorn convention

## Prerequisites

- [just](https://github.com/casey/just) - Command runner
- Python 3.8+ with the following packages:
  - rasterio
  - numpy
  - mercantile
  - imagecodecs
  - pmtiles

Install Python dependencies:
```bash
pip install -r requirements.txt
```

## Installation

1. Install `just`:
   ```bash
   # macOS
   brew install just
   
   # Linux
   cargo install just
   # or use your package manager
   ```

2. Install Python dependencies:
   ```bash
   pip install -r requirements.txt
   ```

## Usage

### Stage 1: Generate Bounds CSV

Prepare your source data by placing GeoTIFF elevation files in a source directory:

```bash
# Create source directory
mkdir -p source-store/freetown

# Place your elevation GeoTIFF files in source-store/freetown/

# Generate bounds.csv with bounding box info
just bounds freetown
```

This creates `source-store/freetown/bounds.csv` containing:
- filename: Name of each GeoTIFF
- left, bottom, right, top: Bounding box in EPSG:3857
- width, height: Raster dimensions in pixels

### Stage 2: Process Tiles (To Be Implemented)

The full tile cutting and encoding pipeline is planned for implementation:

```bash
just process freetown
```

This will:
1. Read bounds.csv to determine tile coverage
2. Cut 512×512 elevation data from source GeoTIFFs  
3. Reproject to EPSG:3857 if needed
4. Apply Terrarium encoding with zoom-dependent vertical rounding
5. Save as lossless WebP tiles
6. Bundle into PMTiles archive

### Configuration

All settings can be customized via environment variables:

```bash
# Custom source and output
SOURCE_NAME="my_dem" OUTPUT_PATH="terrain.pmtiles" just process

# Custom zoom range
MIN_ZOOM=8 MAX_ZOOM=15 just process
```

### Available Tasks

- `just` or `just --list` - Show all available tasks
- `just bounds <source>` - Generate bounds.csv for a source
- `just process <source>` - Process elevation data to PMTiles (WIP)
- `just config` - Display current configuration
- `just clean` - Remove temporary files
- `just clean-all` - Remove all generated files
- `just example-bounds` - Show usage example
- `just test-utils` - Test Python dependencies

## Technical Details

### Terrarium Encoding

Terrarium encoding stores elevation in RGB channels with zoom-dependent precision:

| Zoom | Pixel Size (3857) | Vertical Resolution |
|------|-------------------|---------------------|
| 0    | 78.3 km          | 2048 m             |
| 5    | 2.45 km          | 64 m               |
| 10   | 76.4 m           | 2 m                |
| 15   | 2.39 m           | 6.3 cm             |
| 19   | 0.149 m          | 3.9 mm             |

The encoding uses:
- **Red channel**: High byte (elevation // 256)
- **Green channel**: Low byte (elevation % 256)
- **Blue channel**: Fractional part ((elevation - floor(elevation)) × 256)

### Vertical Rounding

Following mapterhorn methodology, vertical resolution is rounded at lower zoom levels:

```python
factor = 2 ** (19 - z) / 256
rounded_elevation = round(elevation / factor) * factor
```

This optimizes tile size while maintaining appropriate precision for each zoom level.

### Tile Format

- **Size**: 512×512 pixels (standard for terrain tiles)
- **Format**: Lossless WebP (smaller than PNG, maintains exact elevation values)
- **Coordinate System**: EPSG:3857 (Web Mercator)
- **Archive Format**: PMTiles (cloud-optimized single-file archive)

## Project Structure

```
shin-freetown/
├── utils.py              # Terrain encoding utilities (save_terrarium_tile, create_archive)
├── source_bounds.py      # Bounds CSV generation
├── Justfile              # Task definitions
├── requirements.txt      # Python dependencies
├── README.md            # This file
└── source-store/        # Source GeoTIFF data (gitignored)
    └── {source}/
        ├── *.tif        # Elevation GeoTIFFs
        └── bounds.csv   # Generated metadata
```

## Comparison with Mapterhorn

This project is inspired by [mapterhorn](https://github.com/mapterhorn/mapterhorn) but simplified:

- **Mapterhorn**: Full planetary-scale pipeline with aggregation, downsampling, and bundling
- **shin-freetown**: Streamlined for smaller regions with essential terrain encoding features

Key similarities:
- Terrarium RGB encoding with zoom-dependent vertical rounding
- Lossless WebP tile format  
- PMTiles output format
- Bounds CSV for spatial metadata

## Related Projects

- [mapterhorn](https://github.com/mapterhorn/mapterhorn) - Full-featured terrain tile pipeline
- [Protomaps](https://protomaps.com) - PMTiles format and cloud-optimized mapping
- [rio-rgbify](https://github.com/mapbox/rio-rgbify) - Alternative terrain encoding tool

## License

This project is licensed under CC0 1.0 Universal. See [LICENSE](LICENSE) for details.

**Note**: The output terrain data inherits the license of your source elevation data.
