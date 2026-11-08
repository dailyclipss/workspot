import {
  assert,
  assertEquals,
  assertFalse,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  type CallbackStore,
  computeSignature,
  handleEpointCallback,
  type OrderRow,
  parsePremiumVipDays,
  safeEqual,
} from "./handler.ts";

// Dummy key for tests only
const KEY = "test-private-key-not-real";

class FakeStore implements CallbackStore {
  orders = new Map<string, OrderRow & { payment_info?: Record<string, unknown> }>();
  jobUpdates: { id: string; payload: Record<string, unknown> }[] = [];
  failJobUpdates = false;
  reads = 0;
  writes = 0;

  addOrder(o: Partial<OrderRow> & { order_id: string }) {
    this.orders.set(o.order_id, {
      target_id: "job-1",
      target_type: "job",
      package_id: "standard_listing",
      amount: 10,
      status: "pending",
      ...o,
    });
  }
  getOrder(orderId: string) {
    this.reads++;
    return Promise.resolve(this.orders.get(orderId) ?? null);
  }
  markOrder(orderId: string, status: "paid" | "failed", info: Record<string, unknown>) {
    const o = this.orders.get(orderId);
    if (!o || o.status === "paid") return Promise.resolve(false);
    this.writes++;
    o.status = status;
    o.payment_info = info;
    return Promise.resolve(true);
  }
  revertPaidOrder(orderId: string) {
    const o = this.orders.get(orderId);
    if (o?.status === "paid") o.status = "pending";
    return Promise.resolve();
  }
  updateJob(id: string, payload: Record<string, unknown>) {
    if (this.failJobUpdates) return Promise.resolve("boom");
    this.writes++;
    this.jobUpdates.push({ id, payload });
    return Promise.resolve(null);
  }
}

async function callback(
  payload: Record<string, unknown>,
  opts: { signature?: string; key?: string } = {},
) {
  const data = btoa(JSON.stringify(payload));
  const signature = opts.signature ?? await computeSignature(data, opts.key ?? KEY);
  return new Request("https://example.test/epoint-callback", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ data, signature }).toString(),
  });
}

const success = (extra: Record<string, unknown> = {}) => ({
  order_id: "o1",
  status: "success",
  amount: "10.00",
  transaction: "t-1",
  card_name: "MUST NOT BE STORED",
  card_mask: "411111******1111",
  ...extra,
});

function captureConsole() {
  const lines: string[] = [];
  const orig = { log: console.log, error: console.error, warn: console.warn };
  const push = (...a: unknown[]) => lines.push(a.map((x) => JSON.stringify(x)).join(" "));
  console.log = push;
  console.error = push;
  console.warn = push;
  return { lines, restore: () => Object.assign(console, orig) };
}

Deno.test("missing signature -> 400, nothing read or written", async () => {
  const store = new FakeStore();
  const data = btoa(JSON.stringify(success()));
  const req = new Request("https://x.test", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ data }).toString(),
  });
  const res = await handleEpointCallback(req, { privateKey: KEY }, store);
  assertEquals(res.status, 400);
  assertEquals(store.reads + store.writes, 0);
});

Deno.test("wrong signature -> 400, no activation, signatures not logged", async () => {
  const store = new FakeStore();
  store.addOrder({ order_id: "o1" });
  const cap = captureConsole();
  try {
    const bad = "AAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    const payload = success();
    const expected = await computeSignature(btoa(JSON.stringify(payload)), KEY);
    const res = await handleEpointCallback(
      await callback(payload, { signature: bad }),
      { privateKey: KEY },
      store,
    );
    assertEquals(res.status, 400);
    assertEquals(await res.text(), "Invalid Signature");
    assertEquals(store.reads + store.writes, 0);
    assertEquals(store.orders.get("o1")!.status, "pending");
    const logged = cap.lines.join("\n");
    assertFalse(logged.includes(expected));
    assertFalse(logged.includes(bad));
  } finally {
    cap.restore();
  }
});

Deno.test("signature made with another key -> 400", async () => {
  const store = new FakeStore();
  store.addOrder({ order_id: "o1" });
  const res = await handleEpointCallback(
    await callback(success(), { key: "other-key" }),
    { privateKey: KEY },
    store,
  );
  assertEquals(res.status, 400);
  assertEquals(store.jobUpdates.length, 0);
});

Deno.test("no private key configured -> 400 (never skips verification)", async () => {
  const store = new FakeStore();
  store.addOrder({ order_id: "o1" });
  const res = await handleEpointCallback(await callback(success()), {}, store);
  assertEquals(res.status, 400);
  assertEquals(store.jobUpdates.length, 0);
});

Deno.test("valid success -> order paid, job activated, minimal payment_info", async () => {
  const store = new FakeStore();
  store.addOrder({ order_id: "o1" });
  const res = await handleEpointCallback(await callback(success()), { privateKey: KEY }, store);
  assertEquals(res.status, 200);
  const order = store.orders.get("o1")!;
  assertEquals(order.status, "paid");
  assertEquals(Object.keys(order.payment_info!).sort(), ["amount", "order_id", "status", "transaction"]);
  assertEquals(store.jobUpdates.length, 1);
  assertEquals(store.jobUpdates[0].payload.ad_status, "active");
  assertEquals(store.jobUpdates[0].payload.is_vip, false);
});

Deno.test("payload is not logged in full", async () => {
  const store = new FakeStore();
  store.addOrder({ order_id: "o1" });
  const cap = captureConsole();
  try {
    await handleEpointCallback(await callback(success()), { privateKey: KEY }, store);
    const logged = cap.lines.join("\n");
    assertFalse(logged.includes("411111"));
    assertFalse(logged.includes("MUST NOT"));
  } finally {
    cap.restore();
  }
});

Deno.test("replay -> 200 but no second activation, admin rejection survives", async () => {
  const store = new FakeStore();
  store.addOrder({ order_id: "o1" });
  const req1 = await callback(success());
  const req2 = await callback(success());
  assertEquals((await handleEpointCallback(req1, { privateKey: KEY }, store)).status, 200);
  assertEquals(store.jobUpdates.length, 1);
  // admin rejects the job afterwards, then the same callback arrives again
  const res2 = await handleEpointCallback(req2, { privateKey: KEY }, store);
  assertEquals(res2.status, 200);
  assertEquals(store.jobUpdates.length, 1);
  assertEquals(store.orders.get("o1")!.status, "paid");
});

Deno.test("failed callback never overrides a paid order", async () => {
  const store = new FakeStore();
  store.addOrder({ order_id: "o1" });
  await handleEpointCallback(await callback(success()), { privateKey: KEY }, store);
  await handleEpointCallback(
    await callback({ order_id: "o1", status: "failed" }),
    { privateKey: KEY },
    store,
  );
  assertEquals(store.orders.get("o1")!.status, "paid");
});

Deno.test("amount mismatch -> order failed/amount_mismatch, job untouched", async () => {
  const store = new FakeStore();
  store.addOrder({ order_id: "o1", amount: 20, package_id: "premium_listing" });
  const res = await handleEpointCallback(
    await callback(success({ amount: "1.00" })),
    { privateKey: KEY },
    store,
  );
  assertEquals(res.status, 200);
  const order = store.orders.get("o1")!;
  assertEquals(order.status, "failed");
  assertEquals(order.payment_info!.reason, "amount_mismatch");
  assertEquals(store.jobUpdates.length, 0);
});

Deno.test("missing amount in callback is treated as mismatch", async () => {
  const store = new FakeStore();
  store.addOrder({ order_id: "o1" });
  const payload = success();
  delete (payload as Record<string, unknown>).amount;
  await handleEpointCallback(await callback(payload), { privateKey: KEY }, store);
  assertEquals(store.orders.get("o1")!.status, "failed");
  assertEquals(store.jobUpdates.length, 0);
});

Deno.test("amount formatting differences are accepted (10 vs 10.00)", async () => {
  const store = new FakeStore();
  store.addOrder({ order_id: "o1", amount: "10.00" });
  await handleEpointCallback(await callback(success({ amount: 10 })), { privateKey: KEY }, store);
  assertEquals(store.orders.get("o1")!.status, "paid");
});

Deno.test("unknown order -> 200, nothing written", async () => {
  const store = new FakeStore();
  const res = await handleEpointCallback(await callback(success()), { privateKey: KEY }, store);
  assertEquals(res.status, 200);
  assertEquals(store.writes, 0);
});

Deno.test("activation failure -> 500, order reverted, retry activates", async () => {
  const store = new FakeStore();
  store.addOrder({ order_id: "o1" });
  store.failJobUpdates = true;
  const res = await handleEpointCallback(await callback(success()), { privateKey: KEY }, store);
  assertEquals(res.status, 500);
  assertEquals(await res.text(), "Internal error");
  assertEquals(store.orders.get("o1")!.status, "pending");
  store.failJobUpdates = false;
  const retry = await handleEpointCallback(await callback(success()), { privateKey: KEY }, store);
  assertEquals(retry.status, 200);
  assertEquals(store.jobUpdates.length, 1);
  assertEquals(store.orders.get("o1")!.status, "paid");
});

Deno.test("catch returns generic message, not error text", async () => {
  const store = new FakeStore();
  const data = btoa("this is not json");
  const signature = await computeSignature(data, KEY);
  const req = new Request("https://x.test", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ data, signature }).toString(),
  });
  const cap = captureConsole();
  try {
    const res = await handleEpointCallback(req, { privateKey: KEY }, store);
    assertEquals(res.status, 500);
    assertEquals(await res.text(), "Internal error");
  } finally {
    cap.restore();
  }
});

Deno.test("premium: vip_until/vip_expires_at set only when days configured", async () => {
  const withDays = new FakeStore();
  withDays.addOrder({ order_id: "o1", package_id: "premium_listing", amount: 20 });
  const before = Date.now();
  await handleEpointCallback(
    await callback(success({ amount: "20.00" })),
    { privateKey: KEY, premiumVipDays: 30 },
    withDays,
  );
  const p = withDays.jobUpdates[0].payload;
  assertEquals(p.is_vip, true);
  const until = Date.parse(p.vip_until as string);
  assert(until >= before + 30 * 86_400_000 - 1000 && until <= Date.now() + 30 * 86_400_000 + 1000);
  assertEquals(p.vip_expires_at, p.vip_until);

  const noDays = new FakeStore();
  noDays.addOrder({ order_id: "o1", package_id: "premium_listing", amount: 20 });
  await handleEpointCallback(
    await callback(success({ amount: "20.00" })),
    { privateKey: KEY },
    noDays,
  );
  assertEquals(noDays.jobUpdates[0].payload.is_vip, true);
  assertFalse("vip_until" in noDays.jobUpdates[0].payload);

  const standard = new FakeStore();
  standard.addOrder({ order_id: "o1" });
  await handleEpointCallback(await callback(success()), { privateKey: KEY, premiumVipDays: 30 }, standard);
  assertFalse("vip_until" in standard.jobUpdates[0].payload);
});

Deno.test("safeEqual and parsePremiumVipDays", () => {
  assert(safeEqual("abc", "abc"));
  assertFalse(safeEqual("abc", "abd"));
  assertFalse(safeEqual("abc", "abcd"));
  assertEquals(parsePremiumVipDays("30"), 30);
  assertEquals(parsePremiumVipDays(undefined), undefined);
  assertEquals(parsePremiumVipDays("0"), undefined);
  assertEquals(parsePremiumVipDays("abc"), undefined);
  assertStringIncludes("ok", "ok");
});
