import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { amount, description, orderId } = await req.json();

    const publicKey = Deno.env.get('EPOINT_PUBLIC_KEY');
    const privateKey = Deno.env.get('EPOINT_PRIVATE_KEY');

    if (!publicKey || !privateKey) {
      return new Response(JSON.stringify({ error: 'Epoint keys not set' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const data = {
      public_key: publicKey,
      amount: amount || "1.00",
      currency: "AZN",
      language: "az",
      order_id: orderId || `order_${Date.now()}`,
      description: description || "Workspot ödənişi",
      success_redirect_url: "https://workspot.az/payment/success",
      error_redirect_url: "https://workspot.az/payment/error"
    };

    const dataString = JSON.stringify(data);
    const dataBase64 = btoa(unescape(encodeURIComponent(dataString)));

    // SHA-1 imzasının hesablanması
    const encoder = new TextEncoder();
    const signData = encoder.encode(privateKey + dataBase64 + privateKey);
    const hashBuffer = await crypto.subtle.digest('SHA-1', signData);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    const signature = btoa(String.fromCharCode(...hashArray));

    const params = new URLSearchParams();
    params.append('data', dataBase64);
    params.append('sign', signature);

    const response = await fetch('https://epoint.az/api/1/request', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: params.toString(),
    });

    const result = await response.json();

    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});
