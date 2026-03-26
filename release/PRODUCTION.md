# Production Baseline

This repository is operated as a deterministic static archive published at `https://sovereignstandard.co`.

## Baseline

- Walker: `SovereignWalker-1.0.0`
- Kernel: `FoldKernel-1.0.0`
- Fixed step count: `64`
- Live archive range: `0...135`
- Deterministic payload: `data.json`
- Creation-time sidecar: `issuance.json`

## Archive Policy

- Units `0...135` are treated as the current production baseline.
- `data.json`, `sigil.svg`, `front.svg`, `back.svg`, `qr.svg`, and `units.json` are expected to remain byte-stable under the fixed walker and kernel versions.
- `issuance.json` is intentionally excluded from determinism and may differ only when a unit directory is deleted and recreated.
- Any change to walker version, kernel version, scoring weights, entropy derivation, selection rule, step count, or output geometry should be treated as a new production phase and regenerated deliberately.

## Release Procedure

1. Confirm the public base URL in `SovereignStandard/SovereignStandard/Utilities/SiteConfiguration.swift`.
2. Regenerate the production archive with `swift run SovereignStandard generate {0..135}`.
3. Verify committed artifacts with `swift run SovereignStandard verify-all`.
4. Refresh the public hash manifest with `./scripts/update_archive_manifest.sh`.
5. Run `swift test`.
6. Confirm GitHub Pages custom domain and HTTPS settings.
7. Commit and push the release snapshot.

## Backup And Provenance

- The file `release/archive-manifest.sha256` records SHA-256 hashes for the committed public site files and archive outputs.
- Before any new production phase, create a local snapshot archive from the repo root:
  `tar -czf sovereignstandard-production-$(date +%Y%m%d).tar.gz CNAME .nojekyll manifest.webmanifest index.html archive.html unit.html style.css site.js units.json assets output release`
- Store that archive outside the working repository.
