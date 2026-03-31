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

      status.textContent = 'Admin action queued.';
      form.reset();
      actionInput.value = action;
      updateReferenceVisibility();
    } catch (error) {
      status.textContent = error.message || 'Unable to apply admin action.';
    } finally {
      submitButton.disabled = false;
    }
  });
})();
