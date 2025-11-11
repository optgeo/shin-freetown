"""
Terrain tile utilities for shin-freetown.
Based on mapterhorn pipelines/utils.py for Terrarium encoding.
"""
import math
from pathlib import Path

import numpy as np
import mercantile
import imagecodecs
from pmtiles.tile import zxy_to_tileid, tileid_to_zxy, TileType, Compression
from pmtiles.writer import Writer


def get_vertical_rounding_multiplier(z):
    """
    Get the vertical rounding multiplier for a given zoom level.
    
    The vertical resolution is reduced at lower zoom levels to optimize tile size.
    At z=19, the resolution is 1/256 m (~3.9mm). At lower zooms, it's powers of 2 larger.
    
    Args:
        z: Zoom level
        
    Returns:
        Rounding multiplier as integer
    """
    return int(2 ** ((10 - z) / 2) / (1 / 256))


def save_terrarium_tile(data, filepath):
    """
    Encode elevation data as Terrarium RGB and save as lossless WebP.
    
    Terrarium encoding stores elevation in RGB channels:
    - elevation = (R * 256 + G + B / 256) - 32768
    - Supports elevation range: -32768m to +32768m
    - Vertical resolution depends on zoom level (see get_vertical_rounding_multiplier)
    
    The vertical resolution is rounded based on zoom level:
    - z19: 1/256 m (~3.9mm) - full resolution
    - z18: 7.8mm
    - z17: 1.6cm
    - ...
    - z0: 2048m
    
    Args:
        data: 2D numpy array of elevation values in meters (512x512)
        filepath: Output path for the WebP tile (format: {z}-{x}-{y}.webp)
    """
    # Extract zoom level from filename (format: z-x-y.webp)
    filename = Path(filepath).name
    z = int(filename.split('-')[0])
    
    # Apply zoom-dependent vertical rounding
    # Full terrarium resolution of 1/256 at zoom 19
    # Multiples of 2 of full terrarium resolution at lower zooms
    full_resolution_zoom = 19
    factor = 2 ** (full_resolution_zoom - z) / 256
    data = np.round(data / factor) * factor
    
    # Encode to Terrarium RGB
    # Add 32768 to shift elevation range to [0, 65536]
    data += 32768
    
    # Create RGB array
    rgb = np.zeros((512, 512, 3), dtype=np.uint8)
    rgb[..., 0] = data // 256      # Red: high byte
    rgb[..., 1] = data % 256        # Green: low byte  
    rgb[..., 2] = (data - np.floor(data)) * 256  # Blue: fractional part
    
    # Save as lossless WebP
    with open(filepath, 'wb') as f:
        f.write(imagecodecs.webp_encode(rgb, lossless=True))


def create_archive(tmp_folder, out_filepath):
    """
    Bundle individual WebP tiles into a PMTiles archive.
    
    Reads all .webp tiles from tmp_folder, sorts them by tile ID,
    and writes them into a PMTiles archive with proper metadata.
    
    Args:
        tmp_folder: Directory containing {z}-{x}-{y}.webp tiles
        out_filepath: Output PMTiles file path
    """
    from glob import glob
    
    with open(out_filepath, 'wb') as f1:
        writer = Writer(f1)
        min_z = math.inf
        max_z = 0
        min_lon = math.inf
        min_lat = math.inf
        max_lon = -math.inf
        max_lat = -math.inf
        
        # Collect all tile IDs
        tile_ids = []
        for filepath in glob(f'{tmp_folder}/*.webp'):
            filename = Path(filepath).name
            z, x, y = [int(a) for a in filename.replace('.webp', '').split('-')]
            tile_ids.append(zxy_to_tileid(z=z, x=x, y=y))
        tile_ids = sorted(tile_ids)
        
        # Write tiles in sorted order
        for tile_id in tile_ids:
            z, x, y = tileid_to_zxy(tile_id)
            filepath = f'{tmp_folder}/{z}-{x}-{y}.webp'
            with open(filepath, 'rb') as f2:
                writer.write_tile(tile_id, f2.read())
            
            # Update bounds
            max_z = max(max_z, z)
            min_z = min(min_z, z)
            west, south, east, north = mercantile.bounds(x, y, z)
            min_lon = min(min_lon, west)
            min_lat = min(min_lat, south)
            max_lon = max(max_lon, east)
            max_lat = max(max_lat, north)
        
        # Convert bounds to integer format (multiplied by 1e7)
        min_lon_e7 = int(min_lon * 1e7)
        min_lat_e7 = int(min_lat * 1e7)
        max_lon_e7 = int(max_lon * 1e7)
        max_lat_e7 = int(max_lat * 1e7)
        
        # Finalize the archive with metadata
        writer.finalize(
            {
                'tile_type': TileType.WEBP,
                'tile_compression': Compression.NONE,
                'min_zoom': min_z,
                'max_zoom': max_z,
                'min_lon_e7': min_lon_e7,
                'min_lat_e7': min_lat_e7,
                'max_lon_e7': max_lon_e7,
                'max_lat_e7': max_lat_e7,
                'center_zoom': int(0.5 * (min_z + max_z)),
                'center_lon_e7': int(0.5 * (min_lon_e7 + max_lon_e7)),
                'center_lat_e7': int(0.5 * (min_lat_e7 + max_lat_e7)),
            },
            {
                'attribution': '<a href="https://github.com/optgeo/shin-freetown">© shin-freetown</a>',
                'format': 'terrarium',
            },
        )
