import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import {
  clientIp,
  corsHeaders,
  generateOtpCode,
  hashOtp,
  jsonResponse,
  PHONE_PATTERN,
} from '../_shared/otp.ts';

const OTP_LIFETIME_MS = 2 * 60 * 1000;
const RATE_WINDOW_MS = 10 * 60 * 1000;
const MAX_PER_PHONE = 3;
const MAX_PER_IP = 10;

const sendWhatsApp = async (phone: string, otpCode: string): Promise<Response> => {
  try {
    const whatsappToken =
      Deno.env.get('WHATSAPP_TOKEN') ?? Deno.env.get('WHATSAPP_ACCESS_TOKEN');
    const phoneNumberId = Deno.env.get('WHATSAPP_PHONE_NUMBER_ID');
    const messageText = `WorkSpot təsdiq kodunuz: ${otpCode}`;

    const templateName = Deno.env.get('WHATSAPP_TEMPLATE_NAME');
    // Meta-nın test şablonu hello_world parametr qəbul etmir və yalnız en_US dilindədir
    const isHelloWorld = templateName === 'hello_world';
    const templateLang =
      Deno.env.get('WHATSAPP_TEMPLATE_LANG') ?? (isHelloWorld ? 'en_US' : 'az');

    // Meta WhatsApp Cloud API: token və göndərən nömrənin ID-si varsa birbaşa göndəririk
    if (whatsappToken && phoneNumberId) {
      const template = {
        name: templateName,
        language: { code: templateLang },
        ...(isHelloWorld
          ? {}
          : {
            // Authentication şablonu: kod həm gövdədə, həm "copy code" düyməsindədir
            components: [
              { type: 'body', parameters: [{ type: 'text', text: otpCode }] },
              {
                type: 'button',
                sub_type: 'url',
                index: '0',
                parameters: [{ type: 'text', text: otpCode }],
              },
            ],
          }),
      };

      const graphResponse = await fetch(
        `https://graph.facebook.com/v25.0/${phoneNumberId}/messages`,
        {
          method: 'POST',
          headers: {
            'Authorization': 'Bearer ' + whatsappToken,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(
            templateName
              ? { messaging_product: 'whatsapp', to: phone, type: 'template', template }
              : {
                messaging_product: 'whatsapp',
                to: phone,
                type: 'text',
                text: { body: messageText },
              },
          ),
        },
      );

      if (!graphResponse.ok) {
        const responseBody = await graphResponse.text();
        console.error(
          `WhatsApp Cloud API failed (${graphResponse.status}): ${responseBody}`,
        );
        return jsonResponse({ error: 'WhatsApp OTP could not be sent.' }, 502);
      }

      return jsonResponse({ success: true });
    }

    const providerEndpoint = Deno.env.get('WHATSAPP_OTP_PROVIDER_ENDPOINT');
    const providerApiKey =
      Deno.env.get('WHATSAPP_OTP_PROVIDER_API_KEY') ?? whatsappToken;
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
        message: messageText,
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
    return jsonResponse({ error: 'WhatsApp OTP could not be sent.' }, 502);
  }
};

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (request.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed.' }, 405);
  }

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: 'Invalid request body.' }, 400);
  }

  const { phone, otpCode, v } = body ?? {};
  if (typeof phone !== 'string' || !PHONE_PATTERN.test(phone)) {
    return jsonResponse({ error: 'Invalid phone number.' }, 400);
  }

  // LEGACY: app 1.0.0 (30) generates and verifies the code on the client.
  // Remove this branch once 1.0.1+ is live and users have updated.
  if (v !== 2) {
    if (typeof otpCode !== 'string' || !/^\d{6}$/.test(otpCode)) {
      return jsonResponse({ error: 'Invalid phone number or OTP code.' }, 400);
    }
    return await sendWhatsApp(phone, otpCode);
  }

  const reviewPhone = Deno.env.get('REVIEW_PHONE');
  const reviewCode = Deno.env.get('REVIEW_CODE');
  if (reviewPhone && reviewCode && phone === reviewPhone) {
    return jsonResponse({ success: true });
  }

  const pepper = Deno.env.get('OTP_PEPPER');
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!pepper || !supabaseUrl || !serviceKey) {
    console.error('send-whatsapp-otp: server is not configured.');
    return jsonResponse({ error: 'Server is not configured.' }, 500);
  }

  const admin = createClient(supabaseUrl, serviceKey);
  const ip = clientIp(request);
  const now = Date.now();
  const since = new Date(now - RATE_WINDOW_MS).toISOString();

  // Opportunistic cleanup of old rows.
  await admin
    .from('phone_otps')
    .delete()
    .lt('created_at', new Date(now - 24 * 60 * 60 * 1000).toISOString());

  const { count: phoneCount, error: phoneCountError } = await admin
    .from('phone_otps')
    .select('id', { count: 'exact', head: true })
    .eq('phone', phone)
    .gte('created_at', since);
  const { count: ipCount, error: ipCountError } = await admin
    .from('phone_otps')
    .select('id', { count: 'exact', head: true })
    .eq('ip', ip)
    .gte('created_at', since);
  if (phoneCountError || ipCountError) {
    console.error('send-whatsapp-otp rate-limit lookup failed');
    return jsonResponse({ error: 'Server error.' }, 500);
  }
  if ((phoneCount ?? 0) >= MAX_PER_PHONE || (ipCount ?? 0) >= MAX_PER_IP) {
    return jsonResponse({ error: 'Too many requests.' }, 429);
  }

  const code = generateOtpCode();
  const { data: row, error: insertError } = await admin
    .from('phone_otps')
    .insert({
      phone,
      code_hash: await hashOtp(phone, code, pepper),
      expires_at: new Date(now + OTP_LIFETIME_MS).toISOString(),
      ip,
    })
    .select('id')
    .single();
  if (insertError || !row) {
    console.error('send-whatsapp-otp insert failed');
    return jsonResponse({ error: 'Server error.' }, 500);
  }

  const response = await sendWhatsApp(phone, code);
  if (!response.ok) {
    await admin.from('phone_otps').delete().eq('id', row.id);
  }
  return response;
});
