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

    const decodedData = JSON.parse(atob(dataBase64));

    if (decodedData.status === 'success') {
      // Supabase bazasını yeniləyirik
      const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
      const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
      const supabase = createClient(supabaseUrl, supabaseKey);

      await supabase
        .from('orders')
        .update({ status: 'paid', payment_info: decodedData })
        .eq('order_id', decodedData.order_id);
    }

    return new Response('OK', { status: 200 });
  } catch (error) {
    return new Response(error.message, { status: 500 });
  }
});
