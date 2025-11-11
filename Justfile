# shin-freetown - Convert GeoTIFF elevation data to Terrarium PMTiles
# Following mapterhorn methodology for terrain tile generation

# Configuration via environment variables with defaults
source_name := env_var_or_default('SOURCE_NAME', 'freetown')
source_dir := 'source-store/' + source_name
output_path := env_var_or_default('OUTPUT_PATH', source_name + '.pmtiles')
tmp_dir := env_var_or_default('TMP_DIR', '.tmp')

# Tile generation parameters
min_zoom := env_var_or_default('MIN_ZOOM', '10')
max_zoom := env_var_or_default('MAX_ZOOM', '17')
tile_size := '512'

# Default recipe - show help
default:
    @just --list

# Stage 1: Generate bounds.csv for source GeoTIFFs
bounds SOURCE=source_name:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "=== Stage 1: Generating bounds.csv for {{SOURCE}} ==="
    
    # Check if source directory exists
    if [ ! -d "source-store/{{SOURCE}}" ]; then
        echo "Error: source-store/{{SOURCE}} does not exist"
        echo "Please create the directory and place your GeoTIFF files there"
        exit 1
    fi
    
    # Count TIFF files
    tif_count=$(find source-store/{{SOURCE}} -name "*.tif" | wc -l)
    echo "Found $tif_count GeoTIFF files in source-store/{{SOURCE}}"
    
    if [ "$tif_count" -eq 0 ]; then
        echo "Warning: No .tif files found"
    fi
    
    # Run bounds generation
    python source_bounds.py {{SOURCE}}
    
    echo ""
    echo "=== Bounds generation complete! ==="
    echo "Output: source-store/{{SOURCE}}/bounds.csv"

# Stage 2: Process elevation data to Terrarium PMTiles
# Note: This is a placeholder - full implementation requires tile cutting logic
process SOURCE=source_name OUTPUT=output_path:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "=== Stage 2: Processing elevation tiles ==="
    echo "Source: {{SOURCE}}"
    echo "Output: {{OUTPUT}}"
    echo ""
    
    # Check bounds.csv exists
    if [ ! -f "source-store/{{SOURCE}}/bounds.csv" ]; then
        echo "Error: bounds.csv not found for {{SOURCE}}"
        echo "Run 'just bounds {{SOURCE}}' first"
        exit 1
    fi
    
    # Create temp directory
    mkdir -p "{{ tmp_dir }}/{{SOURCE}}"
    
    echo "Note: Full tile cutting and Terrarium encoding pipeline requires"
    echo "additional implementation based on specific data processing needs."
    echo ""
    echo "Key steps to implement:"
    echo "1. Read bounds.csv and determine tile coverage"
    echo "2. For each tile at each zoom level:"
    echo "   - Cut 512x512 elevation data from source GeoTIFFs"
    echo "   - Reproject to EPSG:3857 if needed"
    echo "   - Apply Terrarium encoding using utils.save_terrarium_tile()"
    echo "3. Bundle all tiles using utils.create_archive()"
    echo ""
    echo "See utils.py for encoding functions and mapterhorn pipelines for reference."

# Show current configuration
config:
    @echo "=== Configuration ==="
    @echo "SOURCE_NAME: {{ source_name }}"
    @echo "SOURCE_DIR: {{ source_dir }}"
    @echo "OUTPUT_PATH: {{ output_path }}"
    @echo "MIN_ZOOM: {{ min_zoom }}"
    @echo "MAX_ZOOM: {{ max_zoom }}"
    @echo "TILE_SIZE: {{ tile_size }}"
    @echo "TMP_DIR: {{ tmp_dir }}"

# Clean temporary files
clean:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "Cleaning temporary files..."
    rm -rf "{{ tmp_dir }}"
    @echo "Temporary files cleaned."

# Clean all generated files including output
clean-all: clean
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "Cleaning all generated files..."
    rm -f *.pmtiles
    @echo "All generated files cleaned."

# Example: Run bounds generation for default source
example-bounds:
    @echo "=== Example: Generate bounds.csv ==="
    @echo "1. Create source directory:"
    @echo "   mkdir -p source-store/freetown"
    @echo ""
    @echo "2. Place your GeoTIFF elevation files in:"
    @echo "   source-store/freetown/"
    @echo ""
    @echo "3. Run bounds generation:"
    @echo "   just bounds freetown"
    @echo ""
    @echo "This will create: source-store/freetown/bounds.csv"

# Test utilities (if test data exists)
test-utils:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "=== Testing terrain tile utilities ==="
    
    # Check Python dependencies
    python -c "import numpy; import rasterio; import mercantile; import imagecodecs; from pmtiles.writer import Writer; print('All dependencies available')" || {
        echo "Error: Missing Python dependencies"
        echo "Install with: pip install -r requirements.txt"
        exit 1
    }
    
    echo "Python utilities ready!"
