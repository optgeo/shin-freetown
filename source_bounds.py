"""
Generate bounds.csv for source GeoTIFFs.
Based on mapterhorn pipelines/source_bounds.py.

Usage:
    python source_bounds.py <source_name>
    
Creates: source-store/{source}/bounds.csv

The bounds.csv contains:
- filename: Name of the GeoTIFF file
- left, bottom, right, top: Bounding box in EPSG:3857 (Web Mercator)
- width, height: Raster dimensions in pixels
"""
from glob import glob
import sys
import math
from pathlib import Path

import rasterio
from rasterio.warp import transform_bounds


def main():
    source = None
    if len(sys.argv) > 1:
        source = sys.argv[1]
        print(f'Creating bounds for {source}...')
    else:
        print('Error: source argument missing')
        print('Usage: python source_bounds.py <source_name>')
        sys.exit(1)
    
    # Create source-store directory if it doesn't exist
    source_dir = Path(f'source-store/{source}')
    source_dir.mkdir(parents=True, exist_ok=True)
    
    # Find all GeoTIFF files
    filepaths = sorted(glob(f'source-store/{source}/*.tif'))
    
    if not filepaths:
        print(f'Warning: No .tif files found in source-store/{source}/')
        print('Creating empty bounds.csv')
    
    bounds_file_lines = ['filename,left,bottom,right,top,width,height\n']
    
    for j, filepath in enumerate(filepaths):
        try:
            with rasterio.open(filepath) as src:
                if src.crs is None:
                    raise ValueError(f'CRS not defined on {filepath}')
                
                # Transform bounds to EPSG:3857 (Web Mercator)
                left, bottom, right, top = transform_bounds(
                    src.crs, 'EPSG:3857', *src.bounds
                )
                
                # Validate bounds are finite
                for num in [left, bottom, right, top]:
                    if not math.isfinite(num):
                        raise ValueError(
                            f'Number in bounds is not finite. '
                            f'src.bounds={src.bounds} src.crs={src.crs} '
                            f'bounds={(left, bottom, right, top)}'
                        )
                
                filename = Path(filepath).name
                bounds_file_lines.append(
                    f'{filename},{left},{bottom},{right},{top},{src.width},{src.height}\n'
                )
                
                # Progress indicator
                if j % 100 == 0:
                    print(f'Processed {j} / {len(filepaths)}')
        
        except Exception as e:
            print(f'Error processing {filepath}: {e}')
            continue
    
    # Write bounds.csv
    bounds_file = f'source-store/{source}/bounds.csv'
    with open(bounds_file, 'w') as f:
        f.writelines(bounds_file_lines)
    
    print(f'Complete! Created {bounds_file}')
    print(f'Total files processed: {len(bounds_file_lines) - 1}')


if __name__ == '__main__':
    main()
