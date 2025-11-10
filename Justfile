# shin-freetown - Convert GeoTIFF to lossy WebP PMTiles
# Homage to mapterhorn project

# Configuration via environment variables with defaults
source_url := env_var_or_default('SOURCE_URL', 'https://oin-hotosm-temp.s3.us-east-1.amazonaws.com/690585b76415e43597ffd7ea/0/690585b76415e43597ffd7eb.tif')
output_path := env_var_or_default('OUTPUT_PATH', 'freetown_2025-10-22.pmtiles')
local_tif := env_var_or_default('LOCAL_TIF', 'freetown_2025-10-22.tif')

# Metadata configuration
title := env_var_or_default('TITLE', 'Freetown Urban with Sensitive Areas Blurred')
attribution := env_var_or_default('ATTRIBUTION', 'DroneTM (Ivan Gayton; CC-BY 4.0)')
license := env_var_or_default('LICENSE', 'CC-BY 4.0')
description := env_var_or_default('DESCRIPTION', 'Aerial imagery of Freetown at 4cm resolution, uploaded by Ivan Gayton, captured 2025-10-22. Provider: DroneTM, Platform: UAV, Sensor: DJI Mini 4 Pro')
oin_id := env_var_or_default('OIN_ID', '69075f1de47603686de24fe8')
zoom_range := env_var_or_default('ZOOM_RANGE', '11..21')
# Runtime / performance defaults (can be overridden via environment variables)
omp_threads := env_var_or_default('OMP_NUM_THREADS', '1')
# GDAL cache in MB; set conservatively higher for very large imagery if RAM allows
gdal_cachemax := env_var_or_default('GDAL_CACHEMAX', '2048')
# Number of rio worker processes (keep conservative default to avoid OOM)
rio_jobs := env_var_or_default('RIO_JOBS', '1')

# Tile generation defaults
tile_format := env_var_or_default('TILE_FORMAT', 'WEBP')
tile_size := env_var_or_default('TILE_SIZE', '512')
resampling := env_var_or_default('RESAMPLING', 'bilinear')
# Default output quality for WebP (conservative default to reduce size)
quality := env_var_or_default('QUALITY', '65')

# Default recipe - show help
default:
    @just --list

# Lightweight conversion for small test clips. Use CLIP_TIF and CLIP_OUTPUT env vars to override.
convert-clip:
    #!/usr/bin/env bash
    set -euo pipefail

    CLIP_TIF=${CLIP_TIF:-clip_4x_4096_alpha_nodata.tif}
    CLIP_OUTPUT=${CLIP_OUTPUT:-clip_test.pmtiles}

    echo "=== clip conversion: $CLIP_TIF -> $CLIP_OUTPUT ==="
    # use centralized defaults, allow overrides via env vars
    export OMP_NUM_THREADS=${OMP_NUM_THREADS:-{{ omp_threads }}}
    export GDAL_CACHEMAX=${GDAL_CACHEMAX:-{{ gdal_cachemax }}}
    export RIO_JOBS=${RIO_JOBS:-{{ rio_jobs }}}

    rio -v pmtiles "$CLIP_TIF" "$CLIP_OUTPUT" -j ${RIO_JOBS} \
        --exclude-empty-tiles -f {{ tile_format }} --tile-size {{ tile_size }} --resampling {{ resampling }} --rgba \
        --name "{{ title }}-clip" --attribution "{{ attribution }}" \
        --description "{{ description }} | clip test | license={{ license }} | oin_id={{ oin_id }}" \
        --baselayer \
        --zoom-levels {{ zoom_range }} --co QUALITY={{ quality }}

# Stop any running 'rio pmtiles' processes (graceful then force)
stop:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "Attempting to stop any running 'rio pmtiles' processes (TERM -> wait -> KILL)..."
    for i in 1 2 3; do
        pids=$(pgrep -f 'rio pmtiles' || true)
        if [ -z "$pids" ]; then
            echo "no rio pmtiles processes found"
            exit 0
        fi
        echo "iteration $i: found pids: $pids"
        kill -TERM $pids || true
        sleep 3
        still=$(pgrep -f 'rio pmtiles' || true)
        if [ -z "$still" ]; then
            echo "stopped all rio pmtiles processes"
            exit 0
        fi
        echo "still running after TERM: $still — sending KILL"
        kill -KILL $still || true
        sleep 1
    done

    echo "Done; final list:"
    pgrep -af 'rio pmtiles' || echo '(none)'


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
# Make convert depend on add-alpha so alpha-prep is handled as a prerequisite
convert: add-alpha
    #!/usr/bin/env bash
    set -euo pipefail

    echo "=== shin-freetown: GeoTIFF to PMTiles Conversion ==="
    echo "Source file: {{ local_tif }}"
    echo "Output: {{ output_path }}"
    echo "Attribution: {{ attribution }}"
    echo "License: {{ license }}"
    echo ""

    # Conservative memory/thread settings (tunable via env vars)
    # Use centralized defaults defined at top of the Justfile; allow environment overrides.
    export OMP_NUM_THREADS=${OMP_NUM_THREADS:-{{ omp_threads }}}
    export GDAL_CACHEMAX=${GDAL_CACHEMAX:-{{ gdal_cachemax }}}  # MB (increase for large imagery if RAM allows)
    # Number of rio pmtiles worker processes (default set via 'rio_jobs' above)
    export RIO_JOBS=${RIO_JOBS:-{{ rio_jobs }}}
    # Ensure temporary files are written to workspace .tmp (avoid small /tmp)
    export TMPDIR=${TMPDIR:-"$(pwd)/.tmp"}
    mkdir -p "$TMPDIR"

    echo "Starting conversion..."


    # Gracefully stop any background rio pmtiles runs (if present). This attempts
    # a polite SIGTERM first, waits briefly, then force kills lingering processes.
    if command -v pgrep >/dev/null 2>&1; then
        pids=$(pgrep -f 'rio pmtiles' || true)
        if [ -n "$pids" ]; then
            echo "Found running rio pmtiles processes: $pids"
            echo "Stopping them gracefully (SIGTERM)..."
            kill -TERM $pids || true
            sleep 5
            # if any remain, escalate
            still=$(pgrep -f 'rio pmtiles' || true)
            if [ -n "$still" ]; then
                echo "Some rio processes still running; sending SIGKILL..."
                kill -KILL $still || true
            fi
            echo "Background rio pmtiles processes stopped."
        fi
    fi

    # Ensure input TIFF has an alpha band (create one if needed) and convert
    # black (0,0,0) pixels to transparent where appropriate. The processed
    # file will be written next to the source with suffix '_alpha_nodata.tif'.
    src="{{ local_tif }}"
    alpha_dst="${src%.*}_alpha_nodata.tif"
    echo "Preparing alpha-enabled input: $alpha_dst"

    # alpha preparation is handled by the prerequisite `add-alpha` target
    echo "Ensuring alpha-enabled input via add-alpha (prerequisite)"
    if [ -f "$alpha_dst" ]; then
        conv_src="$alpha_dst"
    else
        echo "Warning: alpha file $alpha_dst not found after add-alpha; falling back to source $src"
        conv_src="$src"
    fi

    # Call rio pmtiles; prefer running inside the conda env created earlier if available
    # If user has micromamba and the 'shin-freetown' env, prefer that; otherwise use system `rio`.
    if command -v micromamba >/dev/null 2>&1 && ~/micromamba/micromamba info --envs >/dev/null 2>&1 2>/dev/null; then
        echo "Using micromamba environment 'shin-freetown' to run rio pmtiles"
        ~/micromamba/micromamba run -n shin-freetown rio -v pmtiles \
            "$conv_src" \
            "{{ output_path }}" \
            -j ${RIO_JOBS} \
            --exclude-empty-tiles \
            -f {{ tile_format }} \
            --tile-size {{ tile_size }} \
            --resampling {{ resampling }} \
            --rgba \
            --name "{{ title }}" \
            --attribution "{{ attribution }}" \
            --description "{{ description }} | license={{ license }} | oin_id={{ oin_id }}" \
            --baselayer \
            --zoom-levels {{ zoom_range }} \
            --co QUALITY={{ quality }}
    else
        rio -v pmtiles \
            "$conv_src" \
            \
            "{{ output_path }}" \
            -j ${RIO_JOBS} \
            --exclude-empty-tiles \
            -f {{ tile_format }} \
            --tile-size {{ tile_size }} \
            --resampling {{ resampling }} \
            --rgba \
            --name "{{ title }}" \
            --attribution "{{ attribution }}" \
            --description "{{ description }} | license={{ license }} | oin_id={{ oin_id }}" \
            --baselayer \
            --zoom-levels {{ zoom_range }} \
            --co QUALITY={{ quality }}
    fi

    echo ""
    echo "=== Conversion complete! ==="
    echo "Output file: {{ output_path }}"

# Clean output files
clean:
    rm -f "{{ output_path }}"
    @echo "Output file cleaned."


# Create an alpha-enabled copy of the main TIFF (adds alpha band)
add-alpha:
    #!/usr/bin/env bash
    set -euo pipefail

    SRC=${LOCAL_TIF:-"{{ local_tif }}"}
    DST="${SRC%.*}_alpha_nodata.tif"

    echo "=== add-alpha: creating alpha-enabled TIFF ==="
    echo "source: $SRC"
    echo "destination: $DST"
    echo "NOTE: this operation may be large (size ~ source size) and take a long time."

    export GDAL_CACHEMAX=${GDAL_CACHEMAX:-1024}
    mkdir -p "$(dirname "$DST")"

    if [ -f "$DST" ]; then
        echo "Destination already exists: $DST (skipping)"
        exit 0
    fi

    if ! command -v gdalwarp >/dev/null 2>&1; then
        echo "Error: gdalwarp not found in PATH. Install GDAL to use add-alpha." >&2
        exit 1
    fi

    # Create alpha-enabled TIFF using gdalwarp -dstalpha
    # Use BIGTIFF=YES for very large source files to avoid "Maximum TIFF file size exceeded" errors.
    # Enable tiling for better IO and set a conservative compressor.
    # Enable GDAL debug output on stderr by default; users can override CPL_DEBUG in their environment.
    export CPL_DEBUG=${CPL_DEBUG:-ON}

    # run gdalwarp with --debug so internal messages and progress go to stderr
    # Treat pure-black pixels as source nodata so they become transparent in the alpha band
    gdalwarp --debug ON -srcnodata "0 0 0" -dstalpha \
        -co BIGTIFF=YES -co TILED=YES -co COMPRESS=DEFLATE -co PREDICTOR=2 \
        "$SRC" "$DST"

    echo "add-alpha complete: $DST"

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
