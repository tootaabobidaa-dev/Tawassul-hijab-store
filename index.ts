// Supabase Edge Function (smooth-handler)
// 1) طلب جديد  -> إشعار لهواتف الأدمن
// 2) تغيّر حالة الطلب إلى "خرج للتوصيل" -> إشعار للعميلة
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

async function sendAll(table: string, userId: string | null, message: string) {
  let q = supabase.from(table).select("*");
  if (userId) q = q.eq("user_id", userId);
  const { data: subs, error } = await q;
  if (error) return { error: error.message };
  let sent = 0, removed = 0, failed = 0;
  await Promise.all((subs || []).map(async (s: any) => {
    try {
      await webpush.sendNotification(
        { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } },
        message,
        { TTL: 86400, urgency: "high" },
      );
      sent++;
    } catch (e: any) {
      if (e && (e.statusCode === 404 || e.statusCode === 410)) {
        await supabase.from(table).delete().eq("id", s.id);
        removed++;
      } else {
        failed++;
        console.error("push failed", e && (e.statusCode || e.message));
      }
    }
  }));
  return { sent, removed, failed };
}

const json = (o: unknown, status = 200) =>
  new Response(JSON.stringify(o), { status, headers: { "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  if (req.headers.get("x-webhook-secret") !== WEBHOOK_SECRET) {
    return new Response("unauthorized", { status: 401 });
  }
  let payload: any = {};
  try { payload = await req.json(); } catch (_) {}
  const event = payload.event || "new_order";
  const o = payload.record || {};

  if (event === "status_changed") {
    // نُشعر العميلة عند خروج الطلب للتوصيل فقط
    if (o.status !== "shipped" || !o.auth_user_id) return json({ skipped: true });
    const message = JSON.stringify({
      title: "🚚 طلبك في الطريق",
      body: `موظف التوصيل في طريقه إليكِ الآن${o.order_number ? " • طلب رقم " + o.order_number : ""}`,
      tag: "order-status-" + (o.id || Date.now()),
      url: "/?orders=1",
    });
    return json(await sendAll("customer_push_subscriptions", o.auth_user_id, message));
  }

  // طلب جديد -> الأدمن
  const total = Number(o.total || 0).toLocaleString("en-US");
  const message = JSON.stringify({
    title: "🔔 طلب جديد - توسل",
    body: `${o.customer_name || "عميلة"} • ${total} ج.س${o.order_number ? " • " + o.order_number : ""}`,
    tag: "order-" + (o.id || Date.now()),
    url: "/admin",
  });
  return json(await sendAll("push_subscriptions", null, message));
});
