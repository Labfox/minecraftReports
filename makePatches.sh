#!/bin/bash

# Usage: ./make_mc_patches.sh ENTRY_DIR OUTPUT_DIR
# Creates patches between all minor versions of the same major version,
# and patches between adjacent majors (only one version per major used).

set -e

ENTRY_DIR="versions"
OUTPUT_DIR="patches"

if [[ -z "$ENTRY_DIR" || -z "$OUTPUT_DIR" ]]; then
    echo "Usage: $0 ENTRY_DIR OUTPUT_DIR"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

declare -A major_to_versions
declare -a majors_sorted

# Parse versions and group by major (major = first two number groups)
for path in "$ENTRY_DIR"/*; do
    [[ -d "$path" ]] || continue
    version=$(basename "$path")
    
    # Extract major: first two numeric parts, e.g. "1.16" from "1.16.1" or "1.16"
    major=$(echo "$version" | grep -oP '^\d+\.\d+')

    # Fallback if no match (e.g. weird names), treat entire version as major
    if [[ -z "$major" ]]; then
        major="$version"
    fi

    major_to_versions["$major"]+="$version "
done

# Sort majors in ascending order (numeric sort on major version)
majors_sorted=( $(printf "%s\n" "${!major_to_versions[@]}" | sort -V) )

# --- 1) Generate patches between all versions of the same major ---
for major in "${majors_sorted[@]}"; do
    read -ra versions <<< "${major_to_versions[$major]}"
    for src in "${versions[@]}"; do
        for dst in "${versions[@]}"; do
            [[ "$src" != "$dst" ]] || continue
            mkdir -p "$OUTPUT_DIR/$src"
            echo "Generating intra-major patch: $src -> $dst"
            diff -urN "$ENTRY_DIR/$src" "$ENTRY_DIR/$dst" > "$OUTPUT_DIR/$src/to_$dst.patch" || echo "  Differences found"
        done
    done
done

# --- 2) Generate patches between adjacent majors ---
for i in "${!majors_sorted[@]}"; do
    curr_major="${majors_sorted[$i]}"
    curr_versions=(${major_to_versions[$curr_major]})
    curr_version="${curr_versions[0]}"  # Representative version of current major
    
    # Previous major
    if (( i > 0 )); then
        prev_major="${majors_sorted[$((i-1))]}"
        prev_versions=(${major_to_versions[$prev_major]})
        prev_version="${prev_versions[0]}"  # Representative version of previous major
        
        mkdir -p "$OUTPUT_DIR/$curr_version"
        mkdir -p "$OUTPUT_DIR/$prev_version"
        
        echo "Generating inter-major patch: $curr_version -> $prev_version"
        diff -urN "$ENTRY_DIR/$curr_version" "$ENTRY_DIR/$prev_version" > "$OUTPUT_DIR/$curr_version/to_$prev_version.patch" || echo "  Differences found"
        
        echo "Generating inter-major patch: $prev_version -> $curr_version"
        diff -urN "$ENTRY_DIR/$prev_version" "$ENTRY_DIR/$curr_version" > "$OUTPUT_DIR/$prev_version/to_$curr_version.patch" || echo "  Differences found"
    fi
done

echo "Done! All patches are in $OUTPUT_DIR"
