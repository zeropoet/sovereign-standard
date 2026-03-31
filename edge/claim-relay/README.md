# Claim Relay

This Cloudflare Worker receives confirmed browser claim submissions and forwards them to GitHub Actions using `repository_dispatch`.

## Why this exists

GitHub Pages is static, so the browser cannot safely commit claim data back into the repository.

The relay solves that by:

1. accepting a claim POST from `standardcontrol.html`
2. forwarding it to GitHub Actions
3. letting the repo-side Swift verifier re-check the front mark and claim hash
4. committing `claims.json` and regenerated `units.json`

## Recommended deployment

Use a Cloudflare Worker.

It is the best fit here because:

- it is fast and inexpensive
- custom domains are simple
- secret management is straightforward
- CORS and GitHub API relay logic are tiny

## Configure

Install dependencies:

```bash
cd edge/claim-relay
npm install
```

Set secrets and vars:

```bash
npx wrangler secret put GITHUB_TOKEN
```

Then set these Worker environment variables in Cloudflare:

- `GITHUB_OWNER`
- `GITHUB_REPO`
- `ALLOWED_ORIGIN`

Default `ALLOWED_ORIGIN` is `https://sovereignstandard.co`.

## Deploy

```bash
cd edge/claim-relay
npm run deploy
```

## Site hookup

After deployment, set the claim endpoint in [`standardcontrol.html`](/Users/zeropoet/WebstormProjects/sovereign-standard/standardcontrol.html) by filling in:

```html
<meta name="sovereign-claim-endpoint" content="https://claims.your-domain.workers.dev">
```

Or point it at a custom domain such as:

```html
<meta name="sovereign-claim-endpoint" content="https://claims.sovereignstandard.co">
```

## Payload

The browser sends:

- `unit`
- `email`
- `name`
- `claimed_at`
- `claim_hash`
- `front_mark`

`front_mark` is the code printed on the artifact front.
