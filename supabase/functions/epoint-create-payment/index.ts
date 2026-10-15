import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { encodeBase64 } from "https://deno.land/std@0.224.0/encoding/base64.ts";

const EPOINT_URL = "https://epoint.az/api/1/request";

// Prices are enforced server-side; the client-sent amount is ignored.
const PACKAGES: Record<string, { amount: number; days: number }> = {
  single_vip_pin: { amount: 15, days: 7 },
  pro_business: { amount: 45, days: 30 },
  enterprise: { amount: 99, days: 30 },
  pro_subscription_monthly: { amount: 3.99, days: 30 },
};
const TARGET_TYPES = ["job", "company", "proSubscription"];
const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, content-type",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// signature = base64(sha1(private_key + data + private_key)), data = base64(json)
async function sign(data: string, privateKey: string) {
  const bytes = new TextEncoder().encode(privateKey + data + privateKey);
  return encodeBase64(await crypto.subtle.digest("SHA-1", bytes));
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const publicKey = Deno.env.get("EPOINT_PUBLIC_KEY");
  const privateKey = Deno.env.get("EPOINT_PRIVATE_KEY");
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const successUrl = Deno.env.get("EPOINT_SUCCESS_URL");
  const errorUrl = Deno.env.get("EPOINT_ERROR_URL");
  if (!publicKey || !privateKey || !successUrl || !errorUrl) {
    return json({ error: "server_not_configured" }, 500);
  }

  // Identify the caller from their JWT; never trust a client-sent user_id.
  const authHeader = req.headers.get("Authorization") ?? "";
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) return json({ error: "unauthorized" }, 401);
  const userId = userData.user.id;

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  const packageId = String(body.package_id ?? "");
  const targetId = String(body.target_id ?? "");
  const targetType = String(body.target_type ?? "");
  const pkg = PACKAGES[packageId];
  if (!pkg || !UUID.test(targetId) || !TARGET_TYPES.includes(targetType)) {
    return json({ error: "invalid_request" }, 400);
  }

  const admin = createClient(supabaseUrl, serviceKey);
  const orderId = crypto.randomUUID();

  const { error: insertError } = await admin.from("transactions").insert({
    reference: orderId,
    user_id: userId,
    job_id: targetType === "job" ? targetId : null,
    target_id: targetId,
    target_type: targetType,
    package_type: packageId,
    package_id: packageId,
    package_name: String(body.description ?? packageId).slice(0, 120),
    amount: pkg.amount,
    currency: "AZN",
    payment_method: "epoint",
    status: "pending",
    created_at: new Date().toISOString(),
  });
  if (insertError) return json({ error: "db_error" }, 500);

  const payload = {
    public_key: publicKey,
    amount: pkg.amount,
    currency: "AZN",
    language: "az",
    order_id: orderId,
    description: `WorkSpot ${packageId}`,
    success_redirect_url: successUrl,
    error_redirect_url: errorUrl,
  };
  const data = encodeBase64(new TextEncoder().encode(JSON.stringify(payload)));
  const signature = await sign(data, privateKey);

  const res = await fetch(EPOINT_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ data, signature }),
  });
  const result = await res.json().catch(() => null);

  if (!res.ok || result?.status !== "success" || !result?.redirect_url) {
    await admin.from("transactions").update({ status: "failed" })
      .eq("reference", orderId);
    return json({ error: "epoint_error" }, 502);
  }

  return json({ redirect_url: result.redirect_url, order_id: orderId });
});
