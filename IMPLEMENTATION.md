# Implementation Guide for Stage 2: Tile Cutting and Encoding

## Overview

Stage 2 of the pipeline involves:
1. Reading bounds.csv to determine tile coverage
2. Cutting 512×512 elevation data from source GeoTIFFs for each tile
3. Reprojecting to EPSG:3857 if needed
4. Applying Terrarium encoding with zoom-dependent vertical rounding
5. Saving as lossless WebP tiles
6. Bundling into PMTiles archive

## Key Components to Implement

### 1. Tile Coverage Calculation

Based on bounds.csv, calculate which Web Mercator tiles are needed:

```python
import mercantile
from rasterio.warp import transform_bounds

def get_tile_coverage(bounds_csv, min_zoom, max_zoom):
    """
    Calculate which tiles are needed based on source bounds.
    
    Args:
        bounds_csv: Path to bounds.csv file
        min_zoom: Minimum zoom level
        max_zoom: Maximum zoom level
        
    Returns:
        Dict mapping zoom levels to sets of (x, y) tile coordinates
    """
    coverage = {}
    
    with open(bounds_csv) as f:
        lines = f.readlines()[1:]  # Skip header
        
        for line in lines:
            filename, left, bottom, right, top, width, height = line.strip().split(',')
            left, bottom, right, top = map(float, [left, bottom, right, top])
            
            # Convert EPSG:3857 bounds to WGS84 for mercantile
            # (mercantile expects lon/lat)
            from pyproj import Transformer
            transformer = Transformer.from_crs("EPSG:3857", "EPSG:4326", always_xy=True)
            west, south = transformer.transform(left, bottom)
            east, north = transformer.transform(right, top)
            
            for z in range(min_zoom, max_zoom + 1):
                tiles = mercantile.tiles(west, south, east, north, z)
                if z not in coverage:
                    coverage[z] = set()
                for tile in tiles:
                    coverage[z].add((tile.x, tile.y))
    
    return coverage
```

### 2. Tile Data Extraction

Extract elevation data for a specific tile:

```python
import rasterio
from rasterio.windows import from_bounds
import numpy as np

def extract_tile_data(tif_path, tile, tile_size=512):
    """
    Extract elevation data for a specific tile.
    
    Args:
        tif_path: Path to source GeoTIFF
        tile: mercantile.Tile object (z, x, y)
        tile_size: Tile size in pixels (default 512)
        
    Returns:
        2D numpy array of elevation values (512x512)
    """
    with rasterio.open(tif_path) as src:
        # Get tile bounds in EPSG:3857
        bounds = mercantile.xy_bounds(tile)
        
        # Read data within bounds
        window = from_bounds(
            bounds.left, bounds.bottom, bounds.right, bounds.top,
            src.transform
        )
        
        # Read and resample to 512x512
        data = src.read(
            1,  # First band (elevation)
            window=window,
            out_shape=(tile_size, tile_size),
            resampling=rasterio.enums.Resampling.bilinear
        )
        
        # Handle NODATA values
        if src.nodata is not None:
            data = np.where(data == src.nodata, np.nan, data)
        
        return data
```

### 3. Processing Pipeline

Main processing function:

```python
from pathlib import Path
from utils import save_terrarium_tile, create_archive

def process_tiles(source_name, min_zoom, max_zoom, output_path):
    """
    Main tile processing pipeline.
    
    Args:
        source_name: Name of the source (e.g., 'freetown')
        min_zoom: Minimum zoom level
        max_zoom: Maximum zoom level
        output_path: Output PMTiles file path
    """
    source_dir = Path(f'source-store/{source_name}')
    bounds_csv = source_dir / 'bounds.csv'
    tmp_dir = Path('.tmp') / source_name
    tmp_dir.mkdir(parents=True, exist_ok=True)
    
    # Get tile coverage
    coverage = get_tile_coverage(str(bounds_csv), min_zoom, max_zoom)
    
    # Process each zoom level
    for z in range(min_zoom, max_zoom + 1):
        print(f'Processing zoom level {z}...')
        
        if z not in coverage:
            continue
            
        for x, y in coverage[z]:
            tile = mercantile.Tile(x=x, y=y, z=z)
            
            # Extract elevation data
            data = extract_tile_data_from_sources(
                source_dir, bounds_csv, tile
            )
            
            # Skip if all NODATA
            if np.all(np.isnan(data)):
                continue
            
            # Save as Terrarium-encoded WebP
            tile_path = tmp_dir / f'{z}-{x}-{y}.webp'
            save_terrarium_tile(data, str(tile_path))
    
    # Create PMTiles archive
    create_archive(str(tmp_dir), output_path)
    
    print(f'Complete! Output: {output_path}')
```

### 4. Multi-Source Merging

If you have multiple overlapping GeoTIFFs, you'll need to merge them:

```python
def extract_tile_data_from_sources(source_dir, bounds_csv, tile):
    """
    Extract and merge tile data from multiple sources.
    
    Priority: Higher resolution sources take precedence.
    """
    # Read all source files that overlap this tile
    sources = []
    with open(bounds_csv) as f:
        for line in f.readlines()[1:]:
            filename, left, bottom, right, top, width, height = line.strip().split(',')
            # Check if source overlaps tile
            # ... (implementation depends on spatial index)
            sources.append((filename, resolution))
    
    # Sort by resolution (highest first)
    sources.sort(key=lambda x: x[1], reverse=True)
    
    # Merge data from all sources
    result = np.full((512, 512), np.nan, dtype=np.float32)
    
    for filename, _ in sources:
        data = extract_tile_data(str(source_dir / filename), tile)
        # Fill in NODATA areas
        mask = np.isnan(result)
        result[mask] = data[mask]
        
        # Stop if no more NODATA
        if not np.any(np.isnan(result)):
            break
    
    return result
```

## Integration with Justfile

Update the `process` recipe in Justfile:

```just
process SOURCE=source_name OUTPUT=output_path:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "=== Stage 2: Processing elevation tiles ==="
    
    # Run the Python processing script
    python -c "
from process_tiles import process_tiles
process_tiles('{{SOURCE}}', {{min_zoom}}, {{max_zoom}}, '{{OUTPUT}}')
"
    
    echo "Complete! Output: {{OUTPUT}}"
```

## Performance Considerations

1. **Parallelization**: Process tiles in parallel using multiprocessing
2. **Memory**: Process in chunks to avoid loading all tiles at once
3. **Caching**: Cache reprojected source data if processing multiple zoom levels
4. **COG Format**: Use Cloud-Optimized GeoTIFF sources for faster random access

## Testing Strategy

1. Start with a small test area (single tile at one zoom level)
2. Verify Terrarium encoding is correct
3. Gradually expand to more tiles and zoom levels
4. Test with actual terrain data to validate vertical resolution

## References

- Mapterhorn pipelines: https://github.com/mapterhorn/mapterhorn/tree/main/pipelines
- Mercantile documentation: https://github.com/mapbox/mercantile
- Rasterio documentation: https://rasterio.readthedocs.io/
- PMTiles specification: https://github.com/protomaps/PMTiles
