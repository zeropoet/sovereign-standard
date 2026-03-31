(() => {
  const form = document.getElementById('admin-form');
  const actionInput = document.getElementById('admin-action');
  const referenceField = document.getElementById('reference-field');
  const status = document.getElementById('admin-status');

  if (!form || !actionInput || !referenceField || !status) {
    return;
  }

  function getEndpoint() {
    return document
      .querySelector('meta[name="sovereign-admin-endpoint"]')
      ?.getAttribute('content')
      ?.trim() || '';
  }

  function updateReferenceVisibility() {
    referenceField.hidden = actionInput.value !== 'set-partner';
  }

  function wait(ms) {
    return new Promise((resolve) => window.setTimeout(resolve, ms));
  }

  async function loadUnitRecord(unit) {
    const response = await fetch('units.json', { cache: 'no-store' });

    if (!response.ok) {
      throw new Error('Unable to load registry');
    }

    const manifest = await response.json();
    const units = Array.isArray(manifest?.units) ? manifest.units : [];
    return units.find((record) => Number(record?.id ?? record?.unit) === Number(unit)) || null;
  }

  async function waitForAdminState(action, unit) {
    const timeoutMs = 180000;
    const intervalMs = 4000;
    const startedAt = Date.now();

    while (Date.now() - startedAt < timeoutMs) {
      const record = await loadUnitRecord(unit);

      if (record) {
        if (action === 'clear-claim' && record.state === 'CLAIMABLE') {
          return record;
        }

        if (action === 'set-partner' && record.state === 'PARTNER') {
          return record;
        }

        if (action === 'clear-partner' && record.state !== 'PARTNER') {
          return record;
        }
      }

      await wait(intervalMs);
    }

    throw new Error('Registry update timed out');
  }

  async function submitAction(payload, token) {
    const endpoint = getEndpoint();

    if (!endpoint) {
      throw new Error('Admin relay is not configured');
    }

    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-admin-token': token
      },
      body: JSON.stringify(payload)
    });

    if (!response.ok) {
      let message = 'Admin relay rejected the request';

      try {
        const data = await response.json();
        if (data?.error) {
          message = data.error;
        }
        if (data?.detail) {
          message = `${message}: ${data.detail}`;
        }
      } catch {
        // Ignore parse failure and use the generic message.
      }

      throw new Error(message);
    }
  }

  actionInput.addEventListener('change', updateReferenceVisibility);
  updateReferenceVisibility();

  form.addEventListener('submit', async (event) => {
    event.preventDefault();

    if (!form.reportValidity()) {
      return;
    }

    const data = new FormData(form);
    const submitButton = form.querySelector('button[type="submit"]');
    const action = String(data.get('action') || '').trim();
    const unit = Number(data.get('unit'));
    const reference = String(data.get('reference') || '').trim();
    const token = String(data.get('token') || '').trim();

    submitButton.disabled = true;
    status.textContent = '';

    try {
      await submitAction(
        {
          action,
          unit,
          reference: action === 'set-partner' ? reference : ''
        },
        token
      );

      status.textContent = 'Admin action queued. Awaiting registry publish...';
      form.reset();
      actionInput.value = action;
      updateReferenceVisibility();

      try {
        await waitForAdminState(action, unit);
        status.textContent = 'Registry updated.';
      } catch {
        status.textContent = 'Admin action queued. Refresh if the registry has not updated yet.';
      }
    } catch (error) {
      status.textContent = error.message || 'Unable to apply admin action.';
    } finally {
      submitButton.disabled = false;
    }
  });
})();
