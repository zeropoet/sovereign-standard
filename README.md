# Sovereign Standard

Sovereign Standard is a deterministic artifact generator and static registry for physical units progressing through state.

This repository contains:

- the Swift package that generates and verifies units
- local engine dependencies in `FoldKernel/` and `SigilEngine/`
- the committed artifact archive in `output/`
- the static public site served from the repo root
- the repo-backed claim ledger in `claims.json`

## Baseline

- Platform target: macOS 13+
- Swift tools version: 5.9
- Walker version: `SovereignWalker-1.0.0`
- Kernel version: `FoldKernel-1.0.0`
- Fixed step count: `64`
- Public base URL: `https://sovereignstandard.co`
- Current committed archive range: units `0...135`

## Repository layout

- `Package.swift` defines the executable package.
- `SovereignStandard/SovereignStandard/` contains the CLI app, generator, writers, verifier, QR generation, and site manifest writer.
- `FoldKernel/` contains the fold primitives and convergence hash machinery.
- `SigilEngine/` contains deterministic sigil geometry and SVG export.
- `Tests/SovereignStandardTests/` contains generator and verifier coverage.
- `output/<unit-id>/` stores generated artifacts for each committed unit.
- `units.json` is the generated public registry manifest written by `sync-site`.
- `claims.json` is the committed claim ledger.
- `partners.json` is the committed partner assignment ledger.
- `private/claim-codes.json` is the generated internal claim-code manifest.
- `standardcontrol.html`, `archive.html`, `index.html`, `style.css`, `site.js`, and `registry.js` make up the main site surface.
- `admin.html` and `admin.js` provide a lightweight admin interface for repo-backed state changes.

## Unit artifacts

Each generated unit is written to `output/<unit-id>/` with:

- `data.json`
- `issuance.json`
- `sigil.svg`
- `qr.svg`
- `front.svg`
- `back.svg`

`data.json` is deterministic for a fixed walker/kernel baseline and includes the unit hash, permutation, event stream, memory, and sigil payload.

`issuance.json` is intentionally separate from the deterministic payload and carries issuance-time metadata.

Rewriting an existing unit refreshes `issuance.json`.

## Registry model

Public site state is derived from `units.json`.

Current public states:

- `CLAIMABLE`
- `CLAIMED`
- `PARTNER`

Claims are committed into `claims.json` and merged into `units.json`.

The public registry does not expose internal claim codes.

Each unit record in `units.json` includes:

- `id`
- `state`
- `created_at`
- `sigil` for non-claimable public states
- public claim metadata for claimable or claimed units
- partner metadata when assigned

## Claims

Claims are repo-backed, not browser-only.

The flow is:

1. A collector opens the tin and enters the internal claim code.
2. The browser submits the claim to the relay.
3. GitHub Actions verifies the claim and commits the result to the repo.
4. The public registry updates from committed state.

The live relay scaffold is in `edge/claim-relay/`.

Partner assignments are repo-backed through `partners.json`.

## CLI

Run commands from the repository root.

Generate specific units:

```bash
swift run SovereignStandard generate 0 1 2
```

Generate comma-separated unit ids:

```bash
swift run SovereignStandard generate 42,43,44
```

Delete units:

```bash
swift run SovereignStandard delete 135
```

Verify stored artifacts against a fresh deterministic recomputation:

```bash
swift run SovereignStandard verify 0 1 42
```

Verify every generated unit currently present in `output/`:

```bash
swift run SovereignStandard verify-all
```

Rebuild the public registry from the existing archive:

```bash
swift run SovereignStandard sync-site
```

`sync-site` also refreshes `units.json` and `private/claim-codes.json` from the committed archive and current repo-backed state.

Persist a confirmed claim from a submission payload file:

```bash
swift run SovereignStandard persist-claim claim-submission.json
```

Clear a committed claim for a unit:

```bash
swift run SovereignStandard clear-claim 0
```

Mark a unit as partner:

```bash
swift run SovereignStandard set-partner 12 "Storefront reference"
```

Remove partner state from a unit:

```bash
swift run SovereignStandard clear-partner 12
```

## Static site

The public site is fully static and published from committed files in the repository root.

- `index.html` is the landing page
- `archive.html` lists units from `units.json`
- `standardcontrol.html?unit=<unit-id>` renders a single unit
- `unit.html` is a compatibility redirect

`registry.js` powers the browser claim flow and local claim submission behavior.

If the production domain changes, update:

- `SovereignStandard/SovereignStandard/Utilities/SiteConfiguration.swift`

and regenerate affected units.

## Determinism and verification

Under a fixed walker/kernel baseline:

- generating the same unit twice produces the same deterministic payload
- committed artifacts can be checked with `verify` or `verify-all`
- the kernel is not modified by claim or site-layer changes

Run the tests with:

```bash
swift test
```

## Deployment

GitHub Pages publishes the committed static site.

GitHub Actions is also used to persist confirmed claims back into the repository.
Admin state changes can be applied from the `Admin Unit State` workflow.

`admin.html` is a browser convenience layer for the same workflow path and should only be used with the secured admin relay.
