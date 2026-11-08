export interface OrderRow {
  order_id: string;
  target_id: string | null;
  target_type: string | null;
  package_id: string | null;
  amount: number | string | null;
  status: string | null;
}

export interface CallbackStore {
  getOrder(orderId: string): Promise<OrderRow | null>;
  // Returns true only if a row was changed. Rows already 'paid' are never touched.
  markOrder(
    orderId: string,
    status: 'paid' | 'failed',
    paymentInfo: Record<string, unknown>,
  ): Promise<boolean>;
  // Puts a 'paid' order back to 'pending' so Epoint's retry can activate the job.
  revertPaidOrder(orderId: string): Promise<void>;
  // Returns an error message, or null on success.
  updateJob(jobId: string, payload: Record<string, unknown>): Promise<string | null>;
}

export interface CallbackEnv {
  privateKey?: string;
  // Duration of the premium VIP in days. When not set, vip_until is not written.
  premiumVipDays?: number;
}

const LISTING_PACKAGES = ['standard_listing', 'premium_listing'];

export function safeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const ab = enc.encode(a);
  const bb = enc.encode(b);
  let diff = ab.length ^ bb.length;
  const n = Math.max(ab.length, bb.length);
  for (let i = 0; i < n; i++) diff |= (ab[i] ?? 0) ^ (bb[i] ?? 0);
  return diff === 0;
}

export async function computeSignature(data: string, privateKey: string): Promise<string> {
  const bytes = new TextEncoder().encode(privateKey + data + privateKey);
  const hash = new Uint8Array(await crypto.subtle.digest('SHA-1', bytes));
  return btoa(String.fromCharCode(...hash));
}

export function parsePremiumVipDays(raw: string | undefined | null): number | undefined {
  const n = Number(raw);
  return Number.isInteger(n) && n > 0 && n <= 3650 ? n : undefined;
}

async function readParams(req: Request) {
  const contentType = req.headers.get('content-type') ?? '';
  let data: string | null = null;
  let sign: string | null = null;

  // Epoint sends form-urlencoded, but JSON and multipart are tolerated
  if (contentType.includes('application/json')) {
    const body = await req.json();
    data = body.data ?? null;
    sign = body.signature ?? body.sign ?? null;
  } else {
    const raw = await req.text();
    if (contentType.includes('multipart/form-data')) {
      const fd = await new Response(raw, { headers: { 'content-type': contentType } }).formData();
      data = fd.get('data') as string | null;
      sign = (fd.get('signature') ?? fd.get('sign')) as string | null;
    } else {
      const params = new URLSearchParams(raw);
      data = params.get('data');
      sign = params.get('signature') ?? params.get('sign');
    }
  }
  // URL-decoding may turn '+' into a space
  return {
    contentType,
    data: data?.replace(/ /g, '+') ?? null,
    sign: sign?.replace(/ /g, '+') ?? null,
  };
}

function amountsMatch(paid: unknown, expected: unknown): boolean {
  const a = Number(paid);
  const b = Number(expected);
  return Number.isFinite(a) && Number.isFinite(b) && Math.abs(a - b) < 0.005;
}

function buildActivationAttempts(order: OrderRow, env: CallbackEnv) {
  const isPremium = order.package_id === 'premium_listing';
  const base = {
    ad_status: 'active',
    status: 'active',
    is_active: true,
    is_vip: isPremium,
    package_type: isPremium ? 'Premium' : 'Standard',
    payment_reference: order.order_id,
  };
  const vip: Record<string, unknown> = {};
  if (isPremium && env.premiumVipDays) {
    const until = new Date(Date.now() + env.premiumVipDays * 86_400_000).toISOString();
    vip.vip_until = until;
    vip.vip_expires_at = until;
  }
  // Fall back to simpler payloads for columns that may be missing
  return [
    { ...base, ...vip },
    { ad_status: 'active', is_active: true, is_vip: isPremium, ...vip },
    { ad_status: 'active' },
  ];
}

const internalError = () => new Response('Internal error', { status: 500 });

export async function handleEpointCallback(
  req: Request,
  env: CallbackEnv,
  store: CallbackStore,
): Promise<Response> {
  try {
    const { contentType, data, sign } = await readParams(req);

    if (!data || !sign || !env.privateKey) {
      console.error('Epoint callback: missing parameter', {
        contentType,
        hasData: !!data,
        hasSignature: !!sign,
        hasPrivateKey: !!env.privateKey,
      });
      return new Response('Bad Request', { status: 400 });
    }

    // Verification happens before anything is decoded or written
    const expected = await computeSignature(data, env.privateKey);
    if (!safeEqual(expected, sign)) {
      console.error('Epoint callback: invalid signature', { dataLength: data.length });
      return new Response('Invalid Signature', { status: 400 });
    }

    const decoded = JSON.parse(new TextDecoder().decode(
      Uint8Array.from(atob(data), (c) => c.charCodeAt(0)),
    ));

    const rawStatus = String(decoded.status ?? '').toLowerCase();
    const newStatus = (rawStatus === 'success' || rawStatus === '1')
      ? 'paid'
      : (rawStatus === 'failed' || rawStatus === 'error' || rawStatus === '0')
      ? 'failed'
      : null;
    const orderId = decoded.order_id ? String(decoded.order_id) : '';

    console.log('Epoint callback', { order_id: orderId, status: rawStatus });

    if (!newStatus || !orderId) return new Response('OK', { status: 200 });

    const paymentInfo: Record<string, unknown> = {
      transaction: decoded.transaction ?? null,
      status: decoded.status ?? null,
      amount: decoded.amount ?? null,
      order_id: orderId,
    };

    const order = await store.getOrder(orderId);
    if (!order) {
      console.warn('Epoint callback: unknown order', orderId);
      return new Response('OK', { status: 200 });
    }

    if (newStatus === 'failed') {
      await store.markOrder(orderId, 'failed', paymentInfo);
      return new Response('OK', { status: 200 });
    }

    if (order.amount !== null && order.amount !== undefined &&
        !amountsMatch(decoded.amount, order.amount)) {
      console.error('Epoint callback: amount mismatch', { order_id: orderId });
      await store.markOrder(orderId, 'failed', { ...paymentInfo, reason: 'amount_mismatch' });
      return new Response('OK', { status: 200 });
    }

    // Only the callback that moves the order to 'paid' may activate the job
    const changed = await store.markOrder(orderId, 'paid', paymentInfo);
    if (!changed) {
      console.warn('Epoint callback: order already processed', orderId);
      return new Response('OK', { status: 200 });
    }

    if (order.target_type === 'job' && order.target_id &&
        order.package_id && LISTING_PACKAGES.includes(order.package_id)) {
      let activated = false;
      for (const payload of buildActivationAttempts(order, env)) {
        const err = await store.updateJob(order.target_id, payload);
        if (!err) {
          activated = true;
          break;
        }
        console.error('job activation attempt failed', err);
      }
      if (!activated) {
        await store.revertPaidOrder(orderId);
        return internalError();
      }
    }

    return new Response('OK', { status: 200 });
  } catch (error) {
    console.error('Epoint callback: unexpected error', String((error as Error)?.message ?? error).slice(0, 200));
    return internalError();
  }
}
