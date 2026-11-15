export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

export const jsonResponse = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });

export function unsupportedOtpVersionResponse(version: unknown): Response | null {
  if (version === 2) return null;
  return jsonResponse(
    { error: 'Please update the WorkSpot app to send an OTP.' },
    426,
  );
}

export const PHONE_PATTERN = /^994(?:10|50|51|55|60|70|77|99)\d{7}$/;

const toHex = (buffer: ArrayBuffer) =>
  Array.from(new Uint8Array(buffer))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');

export async function sha256Hex(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  return toHex(await crypto.subtle.digest('SHA-256', bytes));
}

// Hash is bound to the phone number and a server-side pepper.
export function hashOtp(phone: string, code: string, pepper: string) {
  return sha256Hex(`${phone}:${code}:${pepper}`);
}

// Constant-time comparison of two strings.
export function safeEqual(a: string, b: string): boolean {
  const left = new TextEncoder().encode(a);
  const right = new TextEncoder().encode(b);
  let diff = left.length ^ right.length;
  const length = Math.max(left.length, right.length);
  for (let i = 0; i < length; i++) {
    diff |= (left[i] ?? 0) ^ (right[i] ?? 0);
  }
  return diff === 0;
}

// Uniform 6-digit code using rejection sampling (no modulo bias).
export function generateOtpCode(): string {
  const limit = Math.floor(0x100000000 / 1000000) * 1000000;
  const buffer = new Uint32Array(1);
  do {
    crypto.getRandomValues(buffer);
  } while (buffer[0] >= limit);
  return (buffer[0] % 1000000).toString().padStart(6, '0');
}

export function clientIp(request: Request): string {
  const forwarded = request.headers.get('x-forwarded-for');
  const first = forwarded?.split(',')[0]?.trim();
  return first || request.headers.get('cf-connecting-ip') || 'unknown';
}
