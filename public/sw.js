/* يقدّم كود كل كرت كصفحة حقيقية على الرابط run/<id>.html (كما لو كان ملفًا مستقلًا)
   فيعمل مثل الفتح المحلي ويجلب بيانات قاعدة بيانات الكرت نفسه. الكود يُخزَّن في Cache من view.html بعد تسجيل الدخول. */
const CACHE = "alfaham-run-v1";
const RUN = new URL("run/", self.registration.scope).href;

self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", e => e.waitUntil(self.clients.claim()));

self.addEventListener("fetch", e => {
  const req = e.request;
  if (req.method !== "GET" || !req.url.startsWith(RUN)) return;
  e.respondWith((async () => {
    const c = await caches.open(CACHE);
    const hit = await c.match(req.url.split("?")[0].split("#")[0]);
    if (hit) return hit;
    /* لا توجد نسخة: نعود إلى view.html ليجلبها بعد التحقق من تسجيل الدخول */
    const id = decodeURIComponent(req.url.slice(RUN.length).replace(/\.html.*$/, ""));
    const to = new URL("view.html?id=" + encodeURIComponent(id), self.registration.scope).href;
    return new Response('<!doctype html><meta charset="utf-8"><script>location.replace(' + JSON.stringify(to) + ')<\/script>',
      { headers: { "Content-Type": "text/html;charset=utf-8" } });
  })());
});
