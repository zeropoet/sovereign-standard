# Sovereign Standard

Sovereign Standard is a deterministic artifact generator and static archive site built from the Reference Instrument fold engine.

The core engine preserves:

- FoldKernel integration
- event array encoding
- memory encoding
- convergence hashing
- sigil generation

## Site

The public site is static:

- `index.html` is the landing page
- `archive.html` is the artifact index
- `unit.html?id=<unit-id>` is the per-unit detail page

`units.json` drives the archive view.

## Generator

Run the generator from the repo root:

```bash
swift run SovereignStandard generate 0 1 2
```

`generate` now verifies every written unit before completing.

Delete units:

```bash
swift run SovereignStandard delete 135
```

Verify stored artifacts against a fresh deterministic recomputation:

```bash
swift run SovereignStandard verify 0 1 42
```

Verify every generated unit in `output/`:

```bash
swift run SovereignStandard verify-all
```

Default run:

```bash
swift run SovereignStandard
```

Generated artifacts are written to `output/<unit-id>/`:

- `sigil.svg`
- `qr.svg`
- `front.svg`
- `back.svg`
- `data.json`
- `issuance.json`

Each deterministic `data.json` includes:

- `unit_id`
- `walker_version`
- `kernel_version`
- `step_count`
- permutation
- events
- memory
- hash
- sigil SVG payload

Artifacts are now written without wall-clock metadata so regeneration remains bit-identical for a given unit under fixed walker and kernel versions.

`issuance.json` is intentionally separate and may contain non-deterministic creation-time metadata:

- `creation_date`
- `integrity`

The repository also includes golden-vector tests and a byte-for-byte artifact replay check, and CI runs `swift test` on every push and pull request.

## QR routing

QR codes are generated from the configured public base URL in:

- `SovereignStandard/SovereignStandard/Utilities/SiteConfiguration.swift`

When the final domain changes, update that one file and regenerate affected units.

## Current archive state

The current generated set is:

- units `0...135`

Unit `136+` is intentionally not present right now.
