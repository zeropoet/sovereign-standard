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

Delete units:

```bash
swift run SovereignStandard delete 135
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

Each `data.json` includes:

- permutation
- events
- memory
- hash
- sigil SVG payload
- `creation_date`

`creation_date` is preserved on regeneration once a unit has been written, and the site derives an `Integrity` value from that date across a 12-month duration.

## QR routing

QR codes are generated from the configured public base URL in:

- `SovereignStandard/SovereignStandard/Utilities/SiteConfiguration.swift`

When the final domain changes, update that one file and regenerate affected units.

## Current archive state

The current generated set is:

- units `0...135`

Unit `136+` is intentionally not present right now.
