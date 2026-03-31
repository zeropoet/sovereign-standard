(() => {
  const STORAGE_KEY = 'sovereign-standard.claims.v1';
  const PARTNER_ELIGIBLE_MAX_UNIT = 33;
  const RATE_IN_BYTES = 136;
  const ROTATION_OFFSETS = [
    0, 1, 62, 28, 27,
    36, 44, 6, 55, 20,
    3, 10, 43, 25, 39,
    41, 45, 15, 21, 8,
    18, 2, 61, 56, 14
  ];
  const ROUND_CONSTANTS = [
    0x0000000000000001n, 0x0000000000008082n,
    0x800000000000808an, 0x8000000080008000n,
    0x000000000000808bn, 0x0000000080000001n,
    0x8000000080008081n, 0x8000000000008009n,
    0x000000000000008an, 0x0000000000000088n,
    0x0000000080008009n, 0x000000008000000an,
    0x000000008000808bn, 0x800000000000008bn,
    0x8000000000008089n, 0x8000000000008003n,
    0x8000000000008002n, 0x8000000000000080n,
    0x000000000000800an, 0x800000008000000an,
    0x8000000080008081n, 0x8000000000008080n,
    0x0000000080000001n, 0x8000000080008008n
  ];
  const MASK_64 = (1n << 64n) - 1n;

  let manifestPromise;

  function migrateClaimsStore(claims) {
    if (claims['34']) {
      delete claims['34'];
    }

    return claims;
  }

  function getClaimsStore() {
    try {
      const raw = window.localStorage.getItem(STORAGE_KEY);
      const parsed = raw ? JSON.parse(raw) : {};
      const claims = parsed && typeof parsed === 'object' ? parsed : {};
      const migrated = migrateClaimsStore(claims);
      window.localStorage.setItem(STORAGE_KEY, JSON.stringify(migrated));
      return migrated;
    } catch {
      return {};
    }
  }

  function setClaimsStore(claims) {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(migrateClaimsStore(claims)));
  }

  function formatTimestamp(date) {
    return new Date(date).toISOString();
  }

  function getClaimEndpoint() {
    return document
      .querySelector('meta[name="sovereign-claim-endpoint"]')
      ?.getAttribute('content')
      ?.trim() || '';
  }

  function normalizeManifest(manifest) {
    if (Array.isArray(manifest?.units) && typeof manifest.units[0] === 'number') {
      return {
        units: manifest.units.map((unit) => createFallbackRecord(unit))
      };
    }

    if (Array.isArray(manifest?.units)) {
      return manifest;
    }

    return { units: [] };
  }

  function createFallbackRecord(unit) {
    const isPartnerEligible = unit <= PARTNER_ELIGIBLE_MAX_UNIT;
    const timestamp = new Date().toISOString();
    return {
      unit,
      eligible_for_partner: isPartnerEligible,
      timestamp,
      state: 'CLAIMABLE',
      product: {
        blend: 'Green Sencha / Lemon Balm / Kapoor Tulsi / Ginger',
        version: '1.0'
      },
      physical: {
        tin_serial: `SS-${String(unit).padStart(4, '0')}`,
        engraving_hash: '',
        sigil: `output/${unit}/sigil.svg`
      },
      system: {
        seed: String(unit),
        convergence_hash: '',
        memory_bytes: 0,
        kernel_version: '1.0.0'
      },
      claim: null,
      partner: null
    };
  }

  function mergeUnitRecord(record) {
    const claimStore = getClaimsStore();
    const localClaim = claimStore[String(record.unit)];

    if (!localClaim || record.state === 'PARTNER' || record.claim) {
      return record;
    }

    return {
      ...record,
      state: 'CLAIMED',
      claim: localClaim
    };
  }

  async function loadManifest() {
    if (!manifestPromise) {
      manifestPromise = fetch('units.json', { cache: 'no-store' })
        .then((response) => {
          if (!response.ok) {
            throw new Error('Unable to load registry');
          }
          return response.json();
        })
        .then(normalizeManifest);
    }

    return manifestPromise;
  }

  async function loadRegistry() {
    const manifest = await loadManifest();
    return {
      ...manifest,
      units: manifest.units.map(mergeUnitRecord)
    };
  }

  async function loadUnitRecord(unit) {
    const registry = await loadRegistry();
    return registry.units.find((entry) => Number(entry.unit) === Number(unit)) || null;
  }

  async function claimUnit(unit, payload) {
    const record = await loadUnitRecord(unit);

    if (!record) {
      throw new Error('Unit not found');
    }

    if (record.state !== 'CLAIMABLE') {
      throw new Error('This unit is not claimable');
    }

    const normalizedFrontMark = normalizeFrontMark(payload.frontMark);
    const normalizedExpectedFrontMark = normalizeFrontMark(record.physical?.tin_serial || '');

    if (!normalizedFrontMark || normalizedFrontMark !== normalizedExpectedFrontMark) {
      throw new Error('Front mark verification failed');
    }

    const timestamp = formatTimestamp(new Date());
    const claimHash = keccak256(`${record.system.convergence_hash}${normalizedFrontMark}${payload.email}${timestamp}`);
    const relayEndpoint = getClaimEndpoint();

    if (!relayEndpoint) {
      throw new Error('Claim relay is not configured yet');
    }

    await submitClaimToRelay(relayEndpoint, {
      unit: Number(unit),
      email: payload.email,
      name: payload.name || null,
      claimed_at: timestamp,
      claim_hash: claimHash,
      front_mark: normalizedFrontMark
    });

    const claim = {
      email: payload.email,
      name: payload.name || null,
      location: payload.location || null,
      claimed_at: timestamp,
      claim_hash: claimHash,
      verification: {
        method: 'hash',
        confidence: 1
      }
    };

    const claimStore = getClaimsStore();
    claimStore[String(unit)] = claim;
    setClaimsStore(claimStore);

    return {
      ...record,
      state: 'CLAIMED',
      claim
    };
  }

  async function submitClaimToRelay(endpoint, payload) {
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(payload)
    });

    if (!response.ok) {
      let message = 'Claim relay rejected the request';

      try {
        const data = await response.json();
        if (data?.error) {
          message = data.error;
        }
      } catch {
        // Ignore parse failure and fall back to the generic message.
      }

      throw new Error(message);
    }
  }

  function clearClaim(unit) {
    const claimStore = getClaimsStore();
    delete claimStore[String(unit)];
    setClaimsStore(claimStore);
  }

  function normalizeFrontMark(value) {
    return String(value || '')
      .trim()
      .toUpperCase()
      .replaceAll(/[^A-Z0-9]/g, '');
  }

  function getPublicClaimSignal(record) {
    if (!record?.claim) {
      return null;
    }

    if (record.claim.signal) {
      return record.claim.signal;
    }

    if (record.claim.name) {
      return record.claim.name;
    }

    if (record.claim.email) {
      const [localPart = 'collector'] = record.claim.email.split('@');
      return `${localPart.slice(0, 1).toUpperCase()}${localPart.slice(1, 2)}…`;
    }

    return null;
  }

  function clearManifestCache() {
    manifestPromise = undefined;
  }

  function rotl64(value, shift) {
    if (shift === 0) {
      return value;
    }

    const amount = BigInt(shift);
    return ((value << amount) | (value >> (64n - amount))) & MASK_64;
  }

  function keccakF1600(state) {
    for (let round = 0; round < 24; round += 1) {
      const c = new Array(5).fill(0n);
      const d = new Array(5).fill(0n);
      const b = new Array(25).fill(0n);

      for (let x = 0; x < 5; x += 1) {
        c[x] = state[x] ^ state[x + 5] ^ state[x + 10] ^ state[x + 15] ^ state[x + 20];
      }

      for (let x = 0; x < 5; x += 1) {
        d[x] = c[(x + 4) % 5] ^ rotl64(c[(x + 1) % 5], 1);
      }

      for (let x = 0; x < 5; x += 1) {
        for (let y = 0; y < 5; y += 1) {
          state[x + (5 * y)] = (state[x + (5 * y)] ^ d[x]) & MASK_64;
        }
      }

      for (let x = 0; x < 5; x += 1) {
        for (let y = 0; y < 5; y += 1) {
          const index = x + (5 * y);
          const newX = y;
          const newY = ((2 * x) + (3 * y)) % 5;
          b[newX + (5 * newY)] = rotl64(state[index], ROTATION_OFFSETS[index]);
        }
      }

      for (let x = 0; x < 5; x += 1) {
        for (let y = 0; y < 5; y += 1) {
          const index = x + (5 * y);
          state[index] = (b[index] ^ ((~b[((x + 1) % 5) + (5 * y)]) & b[((x + 2) % 5) + (5 * y)])) & MASK_64;
        }
      }

      state[0] = (state[0] ^ ROUND_CONSTANTS[round]) & MASK_64;
    }
  }

  function keccak256(message) {
    const bytes = new TextEncoder().encode(message);
    const padded = Array.from(bytes);
    padded.push(0x01);

    while ((padded.length % RATE_IN_BYTES) !== RATE_IN_BYTES - 1) {
      padded.push(0x00);
    }

    padded.push(0x80);

    const state = new Array(25).fill(0n);

    for (let offset = 0; offset < padded.length; offset += RATE_IN_BYTES) {
      for (let lane = 0; lane < RATE_IN_BYTES / 8; lane += 1) {
        let value = 0n;

        for (let byte = 0; byte < 8; byte += 1) {
          value |= BigInt(padded[offset + (lane * 8) + byte]) << (8n * BigInt(byte));
        }

        state[lane] = (state[lane] ^ value) & MASK_64;
      }

      keccakF1600(state);
    }

    const output = [];

    for (let lane = 0; output.length < 32; lane += 1) {
      let value = state[lane];

      for (let byte = 0; byte < 8 && output.length < 32; byte += 1) {
        output.push(Number(value & 0xffn));
        value >>= 8n;
      }
    }

    return output.map((byte) => byte.toString(16).padStart(2, '0')).join('');
  }

  window.SovereignRegistry = {
    clearManifestCache,
    clearClaim,
    claimUnit,
    getPublicClaimSignal,
    keccak256,
    loadRegistry,
    loadUnitRecord
  };
})();
