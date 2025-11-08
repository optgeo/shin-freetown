# shin-freetown - Convert GeoTIFF to lossy WebP PMTiles
# Homage to mapterhorn project

# Configuration via environment variables with defaults
source_url := env_var_or_default('SOURCE_URL', 'https://oin-hotosm-temp.s3.us-east-1.amazonaws.com/68bed3070dea6f775adb9b06/0/68bed3070dea6f775adb9b07.tif')
output_path := env_var_or_default('OUTPUT_PATH', 'freetown_main_body.pmtiles')

# Metadata configuration
title := env_var_or_default('TITLE', 'Freetown_Main_body')
attribution := env_var_or_default('ATTRIBUTION', 'HOT (Ivan Gayton)')
license := env_var_or_default('LICENSE', 'CC BY-SA 4.0')
description := env_var_or_default('DESCRIPTION', 'Aerial imagery of Freetown at 4cm resolution, captured 2025-04-16 using UAV (DJI Mini 4 Pro With DroneTM). Provider: HOT, Platform: UAV, Sensor: DJI Mini 4 Pro With DroneTM')
oin_id := env_var_or_default('OIN_ID', '68bed3070dea6f775adb9b06')

# Default recipe - show help
default:
    @just --list

# Convert GeoTIFF to lossy WebP PMTiles
go:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "=== shin-freetown: GeoTIFF to PMTiles Conversion ==="
    echo "Source: {{ source_url }}"
    echo "Output: {{ output_path }}"
    echo "Attribution: {{ attribution }}"
    echo "License: {{ license }}"
    echo ""
    
    # Build rio pmtiles command with metadata
    # Using /vsicurl to access remote GeoTIFF without downloading
    echo "Starting conversion..."
    rio pmtiles \
        "/vsicurl/{{ source_url }}" \
        "{{ output_path }}" \
        --encoding webp \
        --resampling bilinear \
        --add-alpha \
        --title "{{ title }}" \
        --attribution "{{ attribution }}" \
        --description "{{ description }}" \
        --minzoom 10 \
        --maxzoom 22 \
        --pmtiles-metadata "license={{ license }}" \
        --pmtiles-metadata "oin_id={{ oin_id }}" \
        --co QUALITY=75
    
    
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
