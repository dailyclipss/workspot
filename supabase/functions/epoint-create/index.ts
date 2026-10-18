import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const LISTING_PACKAGES: Record<string, number> = {
  standard_listing: 10,
  premium_listing: 20,
};

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const {
      amount,
      description,
      orderId,
      package_id: packageId,
      target_id: bodyTargetId,
      job_id: bodyJobId,
      target_type: targetType,
      user_id: bodyUserId,
    } = await req.json();

    let targetId: string | undefined = bodyTargetId ?? bodyJobId;
    const rawTargetId: string | undefined = targetId;

    const publicKey = Deno.env.get('EPOINT_PUBLIC_KEY');
    const privateKey = Deno.env.get('EPOINT_PRIVATE_KEY');

    if (!publicKey || !privateKey) {
      return new Response(JSON.stringify({ error: 'Epoint keys not set' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const finalOrderId = orderId || `order_${Date.now()}`;

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // Elan paketlərinin qiyməti serverdə təyin olunur; client məbləği nəzərə alınmır.
    const listingAmount = LISTING_PACKAGES[packageId ?? ''];
    const finalAmount = listingAmount ?? amount;

    // user_id yalnız tokendən götürülür; body-dəki dəyər tokenlə uyğun olmalıdır
    let userId: string | null = null;
    const token = req.headers.get('Authorization')?.replace('Bearer ', '');
    if (token) {
      const { data: userData } = await supabase.auth.getUser(token);
      userId = userData?.user?.id ?? null;
    }

    if (bodyUserId && bodyUserId !== userId) {
      return new Response(JSON.stringify({ error: 'user_id does not match the authenticated user' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (listingAmount !== undefined) {
      if (!userId || targetType !== 'job' || !rawTargetId) {
        return new Response(JSON.stringify({ error: 'invalid listing payment request' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      // 'job_<timestamp>' sifariş identifikatorudur; real elan id-sini sifarişdən və ya payment_reference-dən tapırıq
      if (!UUID_PATTERN.test(rawTargetId)) {
        const cleanRef = rawTargetId.replace(/^job_/, '');
        const refCandidates = [rawTargetId, `job_${cleanRef}`];
        let resolved: string | null = null;

        const { data: orderRow } = await supabase
          .from('orders')
          .select('target_id')
          .in('order_id', refCandidates)
          .maybeSingle();
        if (orderRow?.target_id && UUID_PATTERN.test(orderRow.target_id)) {
          resolved = orderRow.target_id;
        }

        if (!resolved) {
          const { data: refJob } = await supabase
            .from('jobs')
            .select('id')
            .in('payment_reference', refCandidates)
            .maybeSingle();
          if (refJob?.id) resolved = String(refJob.id);
        }

        if (!resolved) {
          return new Response(JSON.stringify({ error: 'job not found' }), {
            status: 404,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }
        targetId = resolved;
      }

      // Service-role client RLS-i keçir; sahiblik yoxlaması aşağıda əl ilə aparılır
      const { data: job } = await supabase
        .from('jobs')
        .select('*')
        .eq('id', targetId)
        .maybeSingle();
      if (!job) {
        return new Response(JSON.stringify({ error: 'job not found' }), {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      // owner_id / created_by / user_id sütunlarından hansı doludursa, biri istifadəçiyə uyğun olmalıdır
      const owners = ['owner_id', 'created_by', 'user_id']
        .map((key) => (job as Record<string, unknown>)[key])
        .filter((value) => value !== null && value !== undefined && value !== '');
      if (owners.length > 0 && !owners.includes(userId)) {
        return new Response(JSON.stringify({ error: 'job does not belong to this user' }), {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      const jobStatus = String(
        (job as Record<string, unknown>).ad_status ??
          (job as Record<string, unknown>).status ?? '',
      ).toLowerCase();
      if (owners.length === 0 && jobStatus !== 'pending_payment') {
        return new Response(JSON.stringify({ error: 'job ownership could not be verified' }), {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
    }

    const { error: insertError } = await supabase.from('orders').insert({
      order_id: finalOrderId,
      user_id: userId,
      status: 'pending',
      amount: finalAmount ?? null,
      package_id: packageId ?? null,
      target_id: targetId ?? null,
      target_type: targetType ?? null,
    });

    if (insertError) {
      return new Response(JSON.stringify({ error: insertError.message }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const data = {
      public_key: publicKey,
      amount: finalAmount || "1.00",
      currency: "AZN",
      language: "az",
      order_id: finalOrderId,
      result_url: "https://erlguuogmrgyhuhbecny.supabase.co/functions/v1/epoint-callback",
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
    params.append('signature', signature);

    const response = await fetch('https://epoint.az/api/1/request', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: params.toString(),
    });

    const rawText = await response.text();
    let result: Record<string, unknown>;
    try {
      result = JSON.parse(rawText);
    } catch (_) {
      result = { status: 'error', message: 'Non-JSON response from Epoint', raw: rawText.slice(0, 500) };
    }

    const paymentUrl = (result.redirect_url ?? result.url) as string | undefined;

    if (!response.ok || result.status !== 'success' || !paymentUrl) {
      console.error('Epoint request failed', {
        httpStatus: response.status,
        orderId: finalOrderId,
        result,
      });
      await supabase
        .from('orders')
        .update({ status: 'failed', payment_info: result })
        .eq('order_id', finalOrderId);

      return new Response(
        JSON.stringify({
          error: (result.message as string) || 'Epoint payment request failed',
          epoint_http_status: response.status,
          epoint_response: result,
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 },
      );
    }

    return new Response(JSON.stringify({ ...result, redirect_url: paymentUrl, url: paymentUrl }), {
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
