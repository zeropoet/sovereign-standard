const REQUIRED_FIELDS = [
  'unit',
  'claimed_at',
  'claim_code'
];

const ADMIN_ACTIONS = new Set([
  'clear-claim',
  'set-partner',
  'clear-partner'
]);

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        status: 204,
        headers: corsHeaders(env)
      });
    }

    if (request.method !== 'POST') {
      return json({ error: 'Method not allowed' }, 405, env);
    }

    const url = new URL(request.url);

    const origin = request.headers.get('Origin') || '';
    if (env.ALLOWED_ORIGIN && origin !== env.ALLOWED_ORIGIN) {
      return json({ error: 'Origin not allowed' }, 403, env);
    }

    let payload;
    try {
      payload = await request.json();
    } catch {
      return json({ error: 'Invalid JSON body' }, 400, env);
    }

    if (url.pathname === '/admin') {
      return handleAdminRequest(request, env, payload);
    }

    for (const field of REQUIRED_FIELDS) {
      if (payload[field] === undefined || payload[field] === null || payload[field] === '') {
        return json({ error: `Missing field: ${field}` }, 400, env);
      }
    }

    const missing = [
      !env.GITHUB_TOKEN ? 'GITHUB_TOKEN' : null,
      !env.GITHUB_OWNER ? 'GITHUB_OWNER' : null,
      !env.GITHUB_REPO ? 'GITHUB_REPO' : null
    ].filter(Boolean);

    if (missing.length > 0) {
      return json(
        {
          error: 'Relay is not configured',
          missing
        },
        500,
        env
      );
    }

    const dispatchResponse = await dispatchToGitHub(env, {
      event_type: 'persist-claim',
      client_payload: {
        unit: Number(payload.unit),
        claimed_at: String(payload.claimed_at),
        claim_code: String(payload.claim_code)
      }
    });

    if (!dispatchResponse.ok) {
      return dispatchError(dispatchResponse, env);
    }

    return json(
      {
        ok: true,
        status: 'queued'
      },
      202,
      env
    );
  }
};

async function handleAdminRequest(request, env, payload) {
  const token = request.headers.get('x-admin-token') || '';
  if (!env.ADMIN_TOKEN) {
    return json({ error: 'Admin relay is not configured' }, 500, env);
  }

  if (token !== env.ADMIN_TOKEN) {
    return json({ error: 'Unauthorized' }, 401, env);
  }

  const action = String(payload.action || '').trim();
  const unit = Number(payload.unit);
  const reference = typeof payload.reference === 'string' ? payload.reference.trim() : '';

  if (!ADMIN_ACTIONS.has(action)) {
    return json({ error: 'Invalid admin action' }, 400, env);
  }

  if (!Number.isInteger(unit) || unit < 0) {
    return json({ error: 'Invalid unit number' }, 400, env);
  }

  const dispatchResponse = await dispatchToGitHub(env, {
    event_type: 'admin-unit-state',
    client_payload: {
      action,
      unit,
      reference: reference || null
    }
  });

  if (!dispatchResponse.ok) {
    return dispatchError(dispatchResponse, env);
  }

  return json(
    {
      ok: true,
      status: 'queued'
    },
    202,
    env
  );
}

function dispatchToGitHub(env, body) {
  return fetch(
    `https://api.github.com/repos/${env.GITHUB_OWNER}/${env.GITHUB_REPO}/dispatches`,
    {
      method: 'POST',
      headers: {
        'Accept': 'application/vnd.github+json',
        'Authorization': `Bearer ${env.GITHUB_TOKEN}`,
        'Content-Type': 'application/json',
        'User-Agent': 'sovereign-standard-claim-relay'
      },
      body: JSON.stringify(body)
    }
  );
}

async function dispatchError(dispatchResponse, env) {
  const errorText = await dispatchResponse.text();
  return json(
    {
      error: `GitHub dispatch failed: ${dispatchResponse.status}`,
      detail: errorText.slice(0, 400)
    },
    502,
    env
  );
}

function json(data, status, env) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      ...corsHeaders(env)
    }
  });
}

function corsHeaders(env) {
  return {
    'Access-Control-Allow-Origin': env.ALLOWED_ORIGIN || '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, x-admin-token'
  };
}
