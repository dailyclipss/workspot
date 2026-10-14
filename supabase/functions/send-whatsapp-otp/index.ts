const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const jsonResponse = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (request.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed.' }, 405);
  }

  try {
    const { phone, otpCode } = await request.json();
    if (
      typeof phone !== 'string' ||
      !/^994(?:10|50|51|55|60|70|77|99)\d{7}$/.test(phone) ||
      typeof otpCode !== 'string' ||
      !/^\d{6}$/.test(otpCode)
    ) {
      return jsonResponse({ error: 'Invalid phone number or OTP code.' }, 400);
    }

    const providerEndpoint = Deno.env.get('WHATSAPP_OTP_PROVIDER_ENDPOINT');
    const providerApiKey = Deno.env.get('WHATSAPP_OTP_PROVIDER_API_KEY');
    if (!providerEndpoint || !providerApiKey) {
      console.error('WhatsApp OTP provider configuration is missing.');
      return jsonResponse({ error: 'WhatsApp OTP provider is not configured.' }, 500);
    }

    const providerResponse = await fetch(providerEndpoint, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${providerApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        phone,
        message: `WorkSpot təsdiq kodunuz: ${otpCode}`,
      }),
    });

    if (!providerResponse.ok) {
      const responseBody = await providerResponse.text();
      console.error(
        `WhatsApp OTP provider failed (${providerResponse.status}): ${responseBody}`,
      );
      return jsonResponse({ error: 'WhatsApp OTP could not be sent.' }, 502);
    }

    return jsonResponse({ success: true });
  } catch (error) {
    console.error('send-whatsapp-otp failed:', error);
    return jsonResponse({ error: 'Invalid request body.' }, 400);
  }
});
