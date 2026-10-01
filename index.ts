// Supabase Edge Function: notify-new-order
// تُرسل إشعار Web Push إلى هواتف الأدمن عند تسجيل طلب جديد.
import { createClient } from "npm:@supabase/supabase-js@2";
import webpush from "npm:web-push@3.6.7";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const VAPID_PUBLIC_KEY = Deno.env.get("VAPID_PUBLIC_KEY")!;
const VAPID_PRIVATE_KEY = Deno.env.get("VAPID_PRIVATE_KEY")!;
const VAPID_SUBJECT = Deno.env.get("VAPID_SUBJECT") || "mailto:admin@tawassul.store";
const WEBHOOK_SECRET = Deno.env.get("WEBHOOK_SECRET")!;

webpush.setVapidDetails(VAPID_SUBJECT, VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY);
const supabase = createClient(SUPABASE_URL, SERVICE_KEY);

Deno.serve(async (req) => {
  if (req.headers.get("x-webhook-secret") !== WEBHOOK_SECRET) {
    return new Response("unauthorized", { status: 401 });
  }
  let payload: any = {};
  try { payload = await req.json(); } catch (_) {}
  const o = payload.record || payload || {};

  const total = Number(o.total || 0).toLocaleString("en-US");
  const message = JSON.stringify({
    title: "🔔 طلب جديد - توسل",
    body: `${o.customer_name || "عميلة"} • ${total} ج.س${o.order_number ? " • " + o.order_number : ""}`,
    tag: "order-" + (o.id || Date.now()),
    url: "admin.html",
  });

  const { data: subs, error } = await supabase.from("push_subscriptions").select("*");
  if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500 });

  let sent = 0, removed = 0, failed = 0;
  await Promise.all((subs || []).map(async (s) => {
    try {
      await webpush.sendNotification(
        { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
        message,
        { TTL: 86400, urgency: "high" },
      );
      sent++;
    } catch (e: any) {
      if (e && (e.statusCode === 404 || e.statusCode === 410)) {
        await supabase.from("push_subscriptions").delete().eq("id", s.id);
        removed++;
      } else {
        failed++;
        console.error("push failed", e && (e.statusCode || e.message));
      }
    }
  }));

  return new Response(JSON.stringify({ sent, removed, failed }), {
    headers: { "Content-Type": "application/json" },
  });
});
