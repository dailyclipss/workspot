import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import {
  corsHeaders,
  hashOtp,
  jsonResponse,
  PHONE_PATTERN,
  safeEqual,
} from '../_shared/otp.ts';

const MAX_ATTEMPTS = 5;

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

  const { phone, code } = body ?? {};
  if (
    typeof phone !== 'string' ||
    !PHONE_PATTERN.test(phone) ||
    typeof code !== 'string' ||
    !/^\d{6}$/.test(code)
  ) {
    return jsonResponse({ error: 'Invalid phone number or code.' }, 400);
  }

  const pepper = Deno.env.get('OTP_PEPPER');
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!pepper || !supabaseUrl || !serviceKey) {
    console.error('verify-whatsapp-otp: server is not configured.');
    return jsonResponse({ error: 'Server is not configured.' }, 500);
  }
  const admin = createClient(supabaseUrl, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const reviewPhone = Deno.env.get('REVIEW_PHONE');
  const reviewCode = Deno.env.get('REVIEW_CODE');
  const isReview = !!reviewPhone && !!reviewCode && phone === reviewPhone;

  if (isReview) {
    if (!safeEqual(code, reviewCode!)) {
      return jsonResponse({ error: 'Invalid or expired code.' }, 400);
    }
  } else {
    const { data: row, error: lookupError } = await admin
      .from('phone_otps')
      .select('id, code_hash, attempts')
      .eq('phone', phone)
      .gt('expires_at', new Date().toISOString())
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();
    if (lookupError) {
      console.error('verify-whatsapp-otp lookup failed');
      return jsonResponse({ error: 'Server error.' }, 500);
    }
    if (!row) {
      return jsonResponse({ error: 'Invalid or expired code.' }, 400);
    }
    if (row.attempts >= MAX_ATTEMPTS) {
      return jsonResponse({ error: 'Too many attempts.' }, 429);
    }

    // Count the attempt first; the attempts match guards against parallel guessing.
    const { data: bumped, error: bumpError } = await admin
      .from('phone_otps')
      .update({ attempts: row.attempts + 1 })
      .eq('id', row.id)
      .eq('attempts', row.attempts)
      .select('id');
    if (bumpError) {
      console.error('verify-whatsapp-otp attempt update failed');
      return jsonResponse({ error: 'Server error.' }, 500);
    }
    if (!bumped || bumped.length === 0) {
      return jsonResponse({ error: 'Too many attempts.' }, 429);
    }

    const expected = await hashOtp(phone, code, pepper);
    if (!safeEqual(expected, row.code_hash)) {
      return jsonResponse({ error: 'Invalid or expired code.' }, 400);
    }

    await admin.from('phone_otps').delete().eq('phone', phone);
  }

  // Identity is the phone number; the synthetic email only lets us mint a
  // magic-link token. It is never shown or used for email/password login.
  const email = `p${phone}@phone.workspot.invalid`;
  const { error: createError } = await admin.auth.admin.createUser({
    email,
    email_confirm: true,
    phone,
    phone_confirm: true,
  });
  if (createError) {
    // Already registered is expected for returning users; generateLink decides.
    console.log('verify-whatsapp-otp createUser:', createError.message);
  }

  const { data: link, error: linkError } = await admin.auth.admin.generateLink({
    type: 'magiclink',
    email,
  });
  const tokenHash = link?.properties?.hashed_token;
  if (linkError || !tokenHash) {
    console.error('verify-whatsapp-otp generateLink failed:', linkError?.message);
    return jsonResponse({ error: 'Could not create session.' }, 500);
  }

  return jsonResponse({ token_hash: tokenHash });
});
