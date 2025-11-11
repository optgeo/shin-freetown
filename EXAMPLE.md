# Example Usage Walkthrough

This document provides a complete example of using shin-freetown to convert elevation GeoTIFFs to Terrarium PMTiles.

## Example Dataset

For this example, we'll use a hypothetical set of elevation data for Freetown, Sierra Leone.

### Scenario
- **Source**: 10 GeoTIFF files covering Freetown area
- **Format**: Single-band GeoTIFF with elevation in meters
- **CRS**: UTM Zone 29N (EPSG:32629)
- **Resolution**: 5 meters per pixel
- **Coverage**: ~50 km²

## Step-by-Step Process

### Step 1: Prepare Source Data

```bash
# Create source directory
mkdir -p source-store/freetown

# Copy or download your GeoTIFF files
# Example file structure:
# source-store/freetown/
#   ├── tile_001.tif
#   ├── tile_002.tif
#   ├── tile_003.tif
#   └── ...
```

### Step 2: Install Dependencies

```bash
# Install Python dependencies
pip install -r requirements.txt

# Dependencies installed:
# - rasterio (for reading GeoTIFFs)
# - numpy (for array processing)
# - mercantile (for tile calculations)
# - imagecodecs (for WebP encoding)
# - pmtiles (for PMTiles creation)
```

### Step 3: Generate Bounds CSV

```bash
# Run bounds generation for freetown source
just bounds freetown

# Or with custom source name:
SOURCE_NAME=my_dem just bounds my_dem
```

**Output**: `source-store/freetown/bounds.csv`

```csv
filename,left,bottom,right,top,width,height
tile_001.tif,-1457890.234,927345.678,-1456123.456,929012.345,2048,2048
tile_002.tif,-1456123.456,927345.678,-1454356.789,929012.345,2048,2048
...
```

This CSV contains:
- Bounding box in EPSG:3857 (Web Mercator)
- Original raster dimensions

### Step 4: Review Configuration

```bash
# Check current configuration
just config
```

**Output**:
```
=== Configuration ===
SOURCE_NAME: freetown
SOURCE_DIR: source-store/freetown
OUTPUT_PATH: freetown.pmtiles
MIN_ZOOM: 10
MAX_ZOOM: 17
TILE_SIZE: 512
TMP_DIR: .tmp
```

### Step 5: Process Tiles (When Implemented)

```bash
# Process with default settings
just process freetown

# Or with custom settings:
MIN_ZOOM=12 MAX_ZOOM=16 OUTPUT_PATH=terrain.pmtiles just process freetown
```

**Expected Output**:
```
=== Stage 2: Processing elevation tiles ===
Source: freetown
Output: freetown.pmtiles

Processing zoom level 10...
  Tile 10-512-523: extracted 512x512 elevation data
  Tile 10-512-524: extracted 512x512 elevation data
  ...
Processing zoom level 11...
  ...
Processing zoom level 17...
  ...

Bundling tiles into PMTiles archive...
Complete! Output: freetown.pmtiles
```

### Step 6: Verify Output

```bash
# Check file size
ls -lh freetown.pmtiles

# Inspect PMTiles metadata (requires pmtiles CLI)
pmtiles show freetown.pmtiles

# Expected output:
# {
#   "tile_type": "webp",
#   "min_zoom": 10,
#   "max_zoom": 17,
#   "bounds": [-13.3, 8.4, -13.2, 8.5],
#   "center": [-13.25, 8.45, 14],
#   "format": "terrarium",
#   ...
# }
```

## Understanding the Output

### PMTiles Structure

The output `freetown.pmtiles` is a single-file archive containing:
- **Tiles**: Individual 512×512 WebP images with Terrarium-encoded elevation
- **Metadata**: Bounds, zoom range, attribution, format information
- **Index**: Efficient lookup for serving tiles

### Tile Naming Convention

Inside the archive, tiles are stored with IDs derived from:
- `z`: Zoom level (10-17 in this example)
- `x`: Tile column
- `y`: Tile row

The PMTiles format handles this internally.

### Serving the Tiles

You can serve the PMTiles file using:

1. **PMTiles Server** (local testing):
   ```bash
   pmtiles serve freetown.pmtiles
   # Access at http://localhost:8080/
   ```

2. **Static Hosting** (production):
   - Upload to S3, Cloudflare R2, or similar
   - Use PMTiles client libraries to read directly from URL
   - No server required!

### Using in MapLibre GL JS

```javascript
import maplibregl from 'maplibre-gl';
import { Protocol } from 'pmtiles';

// Register PMTiles protocol
let protocol = new Protocol();
maplibregl.addProtocol('pmtiles', protocol.tile);

const map = new maplibregl.Map({
  container: 'map',
  style: {
    version: 8,
    sources: {
      'terrain': {
        type: 'raster-dem',
        url: 'pmtiles://https://example.com/freetown.pmtiles',
        encoding: 'terrarium'
      }
    },
    layers: [
      {
        id: 'hillshade',
        type: 'hillshade',
        source: 'terrain'
      }
    ]
  }
});
```

## Customization Examples

### Example 1: Low-Zoom Overview

For a low-resolution overview suitable for continent-scale viewing:

```bash
MIN_ZOOM=5 MAX_ZOOM=10 OUTPUT_PATH=freetown_overview.pmtiles just process freetown
```

### Example 2: High-Detail Local Area

For detailed local terrain analysis:

```bash
MIN_ZOOM=14 MAX_ZOOM=19 OUTPUT_PATH=freetown_detail.pmtiles just process freetown
```

### Example 3: Multiple Sources

Process multiple elevation datasets:

```bash
# First source
just bounds dem_source1
SOURCE_NAME=dem_source1 OUTPUT_PATH=area1.pmtiles just process dem_source1

# Second source  
just bounds dem_source2
SOURCE_NAME=dem_source2 OUTPUT_PATH=area2.pmtiles just process dem_source2
```

## Troubleshooting

### Issue: No .tif files found

**Solution**: Ensure GeoTIFF files are in `source-store/{source}/` directory with `.tif` extension.

### Issue: CRS not defined

**Solution**: Your GeoTIFF must have a coordinate reference system defined. Use `gdalinfo` to check:
```bash
gdalinfo source-store/freetown/tile_001.tif | grep "Coordinate System"
```

If missing, add it with:
```bash
gdal_edit.py -a_srs EPSG:32629 source-store/freetown/tile_001.tif
```

### Issue: Memory errors during processing

**Solution**: 
- Process fewer zoom levels at once
- Use smaller tiles (though 512×512 is standard)
- Increase system swap space

### Issue: Bounds appear incorrect

**Solution**: Verify source CRS is correctly set. The bounds.csv uses EPSG:3857, so incorrect source CRS will produce wrong bounds.

## Next Steps

After successfully processing your terrain data:

1. **Test visualization**: Use PMTiles viewer or MapLibre GL JS
2. **Optimize storage**: Consider compression settings
3. **Add metadata**: Include attribution, license info
4. **Deploy**: Upload to CDN or object storage

## Additional Resources

- [PMTiles Viewer](https://protomaps.github.io/PMTiles/): Online viewer for testing
- [MapLibre GL JS Examples](https://maplibre.org/maplibre-gl-js-docs/example/): Integration examples
- [Terrarium Format Spec](https://github.com/tilezen/joerd/blob/master/docs/formats.md#terrarium): Detailed encoding specification
