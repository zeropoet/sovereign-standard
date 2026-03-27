(() => {
  const form = document.querySelector('[data-order-form]');

  if (!form) {
    return;
  }

  const typeInputs = Array.from(form.querySelectorAll('input[name="order_type"]'));
  const status = form.querySelector('[data-order-status]');
  const submitButton = form.querySelector('[data-order-submit]');
  const recipientEmail = form.dataset.orderEmail || '';
  const orderTypeNote = form.querySelector('[data-order-type-note]');
  const individualQuantityInput = form.querySelector('input[name="individual_quantity"]');
  const partnerQuantityInput = form.querySelector('input[name="partner_quantity"]');
  const organizationInput = form.querySelector('input[name="organization"]');
  const panels = {
    individual: form.querySelector('[data-order-panel="individual"]'),
    partner: form.querySelector('[data-order-panel="partner"]')
  };

  const setStatus = (message, tone = 'muted') => {
    if (!status) {
      return;
    }

    status.textContent = message;
    status.dataset.tone = tone;
  };

  const syncPanels = () => {
    const selected = typeInputs.find((input) => input.checked)?.value || 'individual';
    panels.individual.classList.toggle('is-hidden', selected !== 'individual');
    panels.partner.classList.toggle('is-hidden', selected !== 'partner');

    if (individualQuantityInput) {
      individualQuantityInput.required = selected === 'individual';
      individualQuantityInput.disabled = selected !== 'individual';
    }

    if (partnerQuantityInput) {
      partnerQuantityInput.required = selected === 'partner';
      partnerQuantityInput.disabled = selected !== 'partner';
    }

    if (organizationInput) {
      organizationInput.required = selected === 'partner';
      organizationInput.disabled = selected !== 'partner';
    }

    if (orderTypeNote) {
      orderTypeNote.textContent = selected === 'partner'
        ? orderTypeNote.dataset.partnerNote || ''
        : orderTypeNote.dataset.individualNote || '';
    }
  };

  typeInputs.forEach((input) => {
    input.addEventListener('change', syncPanels);
  });

  form.addEventListener('submit', async (event) => {
    event.preventDefault();

    if (!form.reportValidity()) {
      return;
    }

    const data = new FormData(form);

    if ((data.get('company') || '').toString().trim()) {
      setStatus('Submission blocked.', 'error');
      return;
    }

    if (!recipientEmail) {
      setStatus('Order email is not configured yet.', 'error');
      return;
    }

    const orderType = data.get('order_type') === 'partner' ? 'partner' : 'individual';
    const quantity = orderType === 'partner'
      ? Number(data.get('partner_quantity') || 20)
      : Number(data.get('individual_quantity') || 1);

    if (orderType === 'partner' && quantity < 20) {
      setStatus('Partner orders require a minimum of 20 units.', 'error');
      return;
    }

    const payload = {
      orderType,
      name: (data.get('name') || '').toString().trim(),
      email: (data.get('email') || '').toString().trim(),
      quantity,
      organization: (data.get('organization') || '').toString().trim(),
      preferredUnitOrNote: (data.get('individual_note') || '').toString().trim(),
      message: (data.get('message') || '').toString().trim(),
      submittedAt: new Date().toISOString()
    };

    const subject = orderType === 'partner'
      ? `Partner Order Request (${quantity} units)`
      : `Order Request (${quantity} unit${quantity === 1 ? '' : 's'})`;

    const bodyLines = [
      'Sovereign Standard order request',
      '',
      `Order type: ${payload.orderType}`,
      `Name: ${payload.name}`,
      `Email: ${payload.email}`,
      `Quantity: ${payload.quantity}`
    ];

    if (payload.organization) {
      bodyLines.push(`Organization: ${payload.organization}`);
    }

    if (payload.preferredUnitOrNote) {
      bodyLines.push(`Preferred unit or note: ${payload.preferredUnitOrNote}`);
    }

    if (payload.message) {
      bodyLines.push('', 'Message:', payload.message);
    }

    bodyLines.push('', `Submitted from site form: ${payload.submittedAt}`);

    const mailtoHref = `mailto:${encodeURIComponent(recipientEmail)}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(bodyLines.join('\n'))}`;

    submitButton?.setAttribute('disabled', 'true');
    setStatus('Opening your email app...', 'muted');

    window.location.href = mailtoHref;

    window.setTimeout(() => {
      submitButton?.removeAttribute('disabled');
      setStatus(`If your email app did not open, send your request to ${recipientEmail}.`, 'success');
    }, 400);
  });

  syncPanels();
})();
