#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")/.."

mkdir -p release

{
  printf "# SHA-256 manifest for the committed public site and archive\n"
  printf "# Generated from repo root: %s\n" "$(pwd)"
  printf "# Walker: SovereignWalker-1.0.0\n"
  printf "# Kernel: FoldKernel-1.0.0\n"
  printf "# Archive range: 0...135\n"
  printf "\n"

  {
    printf "%s\n" CNAME
    printf "%s\n" .nojekyll
    printf "%s\n" manifest.webmanifest
    printf "%s\n" index.html
    printf "%s\n" archive.html
    printf "%s\n" unit.html
    printf "%s\n" style.css
    printf "%s\n" site.js
    printf "%s\n" units.json
    find assets/favicons -type f | sort
    find output -type f | sort
  } | while IFS= read -r path; do
    shasum -a 256 "$path"
  done
} > release/archive-manifest.sha256
