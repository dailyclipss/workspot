import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  try {
    const formData = await req.formData();
    const dataBase64 = formData.get('data') as string;
    const receivedSign = (formData.get('signature') ?? formData.get('sign')) as string;

    const privateKey = Deno.env.get('EPOINT_PRIVATE_KEY');

    if (!dataBase64 || !receivedSign || !privateKey) {
      return new Response('Bad Request', { status: 400 });
    }

    // İmzanı yoxlayırıq
    const encoder = new TextEncoder();
    const signData = encoder.encode(privateKey + dataBase64 + privateKey);
    const hashBuffer = await crypto.subtle.digest('SHA-1', signData);
    const hashArray = Array.from(new Uint8Array(hashBuffer));
    const expectedSignature = btoa(String.fromCharCode(...hashArray));

    if (expectedSignature !== receivedSign) {
      return new Response('Invalid Signature', { status: 400 });
    }

    const decodedData = JSON.parse(new TextDecoder().decode(
      Uint8Array.from(atob(dataBase64), (c) => c.charCodeAt(0)),
    ));
    console.log('Epoint callback', decodedData);

    const rawStatus = String(decodedData.status ?? '').toLowerCase();
    const newStatus = (rawStatus === 'success' || rawStatus === '1')
      ? 'paid'
      : (rawStatus === 'failed' || rawStatus === 'error' || rawStatus === '0')
      ? 'failed'
      : null;

    if (newStatus && decodedData.order_id) {
      const supabase = createClient(
        Deno.env.get('SUPABASE_URL')!,
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      );

      // Ödənilmiş sifarişin statusu geri 'failed'-ə dəyişməsin
      const { data: updated, error: updateError } = await supabase
        .from('orders')
        .update({ status: newStatus, payment_info: decodedData })
        .eq('order_id', decodedData.order_id)
        .neq('status', 'paid')
        .select('order_id');

      if (updateError) {
        console.error('orders update failed', updateError);
        return new Response(updateError.message, { status: 500 });
      }
      if (!updated || updated.length === 0) {
        console.warn('No order updated for', decodedData.order_id);
      }
    }

    return new Response('OK', { status: 200 });
  } catch (error) {
    return new Response(error.message, { status: 500 });
  }
});
