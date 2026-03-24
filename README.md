# Sovereign Standard

Phase 0 extracts the deterministic fold engine from Reference Instrument and prepares it for batch artifact generation.

Preserved core systems:

- FoldKernel integration
- event encoding
- memory encoding
- convergence hashing
- sigil generation

CLI generation writes unit artifacts to `output/<unit-id>/`:

- `sigil.svg`
- `qr.svg`
- `front.svg`
- `back.svg`
- `data.json`

Default run:

```bash
swift run SovereignStandard
```
