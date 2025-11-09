# shin-freetown - Convert GeoTIFF to lossy WebP PMTiles
# Homage to mapterhorn project

# Configuration via environment variables with defaults
source_url := env_var_or_default('SOURCE_URL', 'https://oin-hotosm-temp.s3.us-east-1.amazonaws.com/690585b76415e43597ffd7ea/0/690585b76415e43597ffd7eb.tif')
output_path := env_var_or_default('OUTPUT_PATH', 'freetown_2025-10-22.pmtiles')
local_tif := env_var_or_default('LOCAL_TIF', 'freetown_2025-10-22.tif')

# Metadata configuration
title := env_var_or_default('TITLE', 'Freetown Urban with Sensitive Areas Blurred')
attribution := env_var_or_default('ATTRIBUTION', 'Ivan Gayton')
license := env_var_or_default('LICENSE', 'CC-BY 4.0')
description := env_var_or_default('DESCRIPTION', 'Aerial imagery of Freetown at 4cm resolution, uploaded by Ivan Gayton, captured 2025-10-22. Provider: DroneTM, Platform: UAV, Sensor: DJI Mini 4 Pro')
oin_id := env_var_or_default('OIN_ID', '69075f1de47603686de24fe8')

# Default recipe - show help
default:
    @just --list

# Download the remote GeoTIFF to a local file
download:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "=== shin-freetown: Download source GeoTIFF ==="
    echo "Source URL: {{ source_url }}"
    echo "Destination: {{ local_tif }}"
    echo ""

    mkdir -p "$(dirname "{{ local_tif }}")" || true

    # Prefer aria2c for parallel segmented download; fallback to curl/wget
    if command -v aria2c >/dev/null 2>&1; then
        echo "Downloading with aria2c (concurrency=3, resume supported)..."
        # -c : continue, -x 3 : max connections per server, -s 3 : split into 3 segments
        # -k 1M : minimum split size (helps with large files), -o output
        aria2c -c -x 3 -s 3 -k 1M -o "{{ local_tif }}" "{{ source_url }}"
    elif command -v curl >/dev/null 2>&1; then
        echo "Downloading with curl (resume supported)..."
        curl -L --fail --progress-bar -C - -o "{{ local_tif }}" "{{ source_url }}"
    elif command -v wget >/dev/null 2>&1; then
        echo "Downloading with wget (resume supported)..."
        wget -c -O "{{ local_tif }}" "{{ source_url }}"
    else
        echo "Error: neither aria2c, curl, nor wget is installed. Install one to use the download task." >&2
        exit 1
    fi

    echo ""
    echo "=== Download complete: {{ local_tif }} ==="


# Convert local GeoTIFF to lossy WebP PMTiles
convert:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "=== shin-freetown: GeoTIFF to PMTiles Conversion ==="
    echo "Source file: {{ local_tif }}"
    echo "Output: {{ output_path }}"
    echo "Attribution: {{ attribution }}"
    echo "License: {{ license }}"
    echo ""

    # Conservative memory/thread settings
    export OMP_NUM_THREADS=${OMP_NUM_THREADS:-1}
    export GDAL_CACHEMAX=${GDAL_CACHEMAX:-512}  # MB
    # Ensure temporary files are written to workspace .tmp (avoid small /tmp)
    export TMPDIR=${TMPDIR:-"$(pwd)/.tmp"}
    mkdir -p "$TMPDIR"

    echo "Starting conversion..."

    # Call rio pmtiles; prefer running inside the conda env created earlier if available
    # If user has micromamba and the 'shin-freetown' env, prefer that; otherwise use system `rio`.
    if command -v micromamba >/dev/null 2>&1 && ~/micromamba/micromamba info --envs >/dev/null 2>&1 2>/dev/null; then
        echo "Using micromamba environment 'shin-freetown' to run rio pmtiles"
        ~/micromamba/micromamba run -n shin-freetown rio pmtiles \
            "{{ local_tif }}" \
            "{{ output_path }}" \
            -j 2 \
            --exclude-empty-tiles \
            -f WEBP \
            --tile-size 512 \
            --resampling bilinear \
            --rgba \
            --name "{{ title }}" \
            --attribution "{{ attribution }}" \
            --description "{{ description }} | license={{ license }} | oin_id={{ oin_id }}" \
                --zoom-levels 10..21 \
            --co QUALITY=75
    else
        rio pmtiles \
            "{{ local_tif }}" \
            "{{ output_path }}" \
            -j 2 \
            --exclude-empty-tiles \
            -f WEBP \
            --tile-size 512 \
            --resampling bilinear \
            --rgba \
            --name "{{ title }}" \
            --attribution "{{ attribution }}" \
            --description "{{ description }} | license={{ license }} | oin_id={{ oin_id }}" \
                --zoom-levels 10..21 \
            --co QUALITY=75
    fi

    echo ""
    echo "=== Conversion complete! ==="
    echo "Output file: {{ output_path }}"

# Clean output files
clean:
    rm -f "{{ output_path }}"
    @echo "Output file cleaned."

# Show current configuration
config:
    @echo "=== Configuration ==="
    @echo "SOURCE_URL: {{ source_url }}"
    @echo "OUTPUT_PATH: {{ output_path }}"
    @echo "TITLE: {{ title }}"
    @echo "ATTRIBUTION: {{ attribution }}"
    @echo "LICENSE: {{ license }}"
    @echo "DESCRIPTION: {{ description }}"
    @echo "OIN_ID: {{ oin_id }}"
