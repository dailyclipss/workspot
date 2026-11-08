import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  type CallbackStore,
  handleEpointCallback,
  parsePremiumVipDays,
} from "./handler.ts";

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

const store: CallbackStore = {
  async getOrder(orderId) {
    const { data, error } = await supabase
      .from('orders')
      .select('order_id, target_id, target_type, package_id, amount, status')
      .eq('order_id', orderId)
      .maybeSingle();
    if (error) throw new Error(`orders select failed: ${error.message}`);
    return data;
  },

  async markOrder(orderId, status, paymentInfo) {
    const { data, error } = await supabase
      .from('orders')
      .update({ status, payment_info: paymentInfo })
      .eq('order_id', orderId)
      .neq('status', 'paid')
      .select('order_id');
    if (error) throw new Error(`orders update failed: ${error.message}`);
    return (data?.length ?? 0) > 0;
  },

  async revertPaidOrder(orderId) {
    const { error } = await supabase
      .from('orders')
      .update({ status: 'pending' })
      .eq('order_id', orderId)
      .eq('status', 'paid');
    if (error) console.error('orders revert failed', error.message);
  },

  async updateJob(jobId, payload) {
    const { error } = await supabase.from('jobs').update(payload).eq('id', jobId);
    return error ? error.message : null;
  },
};

serve((req) =>
  handleEpointCallback(
    req,
    {
      privateKey: Deno.env.get('EPOINT_PRIVATE_KEY') ?? undefined,
      premiumVipDays: parsePremiumVipDays(Deno.env.get('EPOINT_PREMIUM_VIP_DAYS')),
    },
    store,
  )
);
