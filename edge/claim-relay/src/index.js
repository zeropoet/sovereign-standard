const REQUIRED_FIELDS = [
  'unit',
  'email',
  'claimed_at',
  'claim_hash',
  'front_mark'
];

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

    const dispatchResponse = await fetch(
      `https://api.github.com/repos/${env.GITHUB_OWNER}/${env.GITHUB_REPO}/dispatches`,
      {
        method: 'POST',
        headers: {
          'Accept': 'application/vnd.github+json',
          'Authorization': `Bearer ${env.GITHUB_TOKEN}`,
          'Content-Type': 'application/json',
          'User-Agent': 'sovereign-standard-claim-relay'
        },
        body: JSON.stringify({
          event_type: 'persist-claim',
          client_payload: {
            unit: Number(payload.unit),
            email: String(payload.email),
            name: payload.name ? String(payload.name) : null,
            claimed_at: String(payload.claimed_at),
            claim_hash: String(payload.claim_hash),
            front_mark: String(payload.front_mark)
          }
        })
      }
    );

    if (!dispatchResponse.ok) {
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
    'Access-Control-Allow-Headers': 'Content-Type'
  };
}
