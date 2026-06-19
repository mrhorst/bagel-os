const VERSION = "v2";
const ASSET_CACHE = `assets-${VERSION}`;
const SHELL_CACHE = `shell-${VERSION}`;
const CURRENT_CACHES = [ASSET_CACHE, SHELL_CACHE];

// The offline fallback is precached so a navigation can always resolve to a
// branded "you're offline" screen instead of the browser error page. We don't
// precache app pages: Bagel OS shouldn't serve stale inventory/price/task data
// offline (acting on yesterday's numbers is worse than knowing you're offline).
const OFFLINE_URL = "/offline.html";
const SHELL_ASSETS = [OFFLINE_URL, "/icon.png"];

self.addEventListener("install", (event) => {
  event.waitUntil(
    (async () => {
      const cache = await caches.open(SHELL_CACHE);
      await cache.addAll(SHELL_ASSETS);
      self.skipWaiting();
    })()
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    (async () => {
      const keys = await caches.keys();
      await Promise.all(
        keys.filter((k) => !CURRENT_CACHES.includes(k)).map((k) => caches.delete(k))
      );
      await self.clients.claim();
    })()
  );
});

self.addEventListener("fetch", (event) => {
  const request = event.request;
  if (request.method !== "GET") return;

  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  // App pages: always try the network so data is fresh; if the network is
  // gone, show the offline fallback rather than the browser error page.
  if (request.mode === "navigate") {
    event.respondWith(
      (async () => {
        try {
          return await fetch(request);
        } catch (_error) {
          const cache = await caches.open(SHELL_CACHE);
          return (await cache.match(OFFLINE_URL)) || Response.error();
        }
      })()
    );
    return;
  }

  const isAsset =
    url.pathname.startsWith("/assets/") ||
    url.pathname === "/icon.png" ||
    url.pathname === "/icon.svg";

  if (isAsset) {
    event.respondWith(
      caches.open(ASSET_CACHE).then(async (cache) => {
        const cached = await cache.match(request);
        if (cached) return cached;
        const response = await fetch(request);
        if (response.ok) cache.put(request, response.clone());
        return response;
      })
    );
  }
});

// ── Web Push ───────────────────────────────────────────────────────────────
// The server sends an encrypted JSON payload ({ title, body, url, tag }) via
// the push service; we turn it into a system notification.
self.addEventListener("push", (event) => {
  if (!event.data) return;

  let payload;
  try {
    payload = event.data.json();
  } catch (_error) {
    payload = { title: "Notification", body: event.data.text() };
  }

  const title = payload.title || "Notification";
  const options = {
    body: payload.body || "",
    icon: "/icon.png",
    badge: "/icon.png",
    tag: payload.tag || undefined,
    data: { url: payload.url || "/" },
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

// Tapping a notification focuses an existing tab on that URL, or opens one.
self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const targetUrl = (event.notification.data && event.notification.data.url) || "/";

  event.waitUntil(
    (async () => {
      const clients = await self.clients.matchAll({
        type: "window",
        includeUncontrolled: true,
      });
      for (const client of clients) {
        if (client.url.includes(targetUrl) && "focus" in client) {
          return client.focus();
        }
      }
      if (self.clients.openWindow) return self.clients.openWindow(targetUrl);
    })()
  );
});
