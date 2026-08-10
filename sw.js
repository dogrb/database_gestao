/* Dog do Rubão — service worker das notificações.
   Só cuida de notificação. Não guarda cache de página, para o sistema
   nunca abrir uma versão velha depois de um deploy. */

self.addEventListener('install', e => self.skipWaiting());
self.addEventListener('activate', e => e.waitUntil(self.clients.claim()));

self.addEventListener('push', event => {
  let d = {};
  try { d = event.data ? event.data.json() : {}; } catch (e) { d = { titulo: 'Dog do Rubão', corpo: event.data ? event.data.text() : '' }; }

  const titulo = d.titulo || 'Dog do Rubão';
  const alta = d.urgencia === 'alta';

  event.waitUntil(self.registration.showNotification(titulo, {
    body: d.corpo || '',
    icon: '/icone-192.png',
    badge: '/icone-192.png',
    tag: d.tag || 'dogrb',
    renotify: alta,
    requireInteraction: alta,
    vibrate: alta ? [200, 80, 200, 80, 200] : [120],
    data: { pagina: d.pagina || 'painel' }
  }));
});

self.addEventListener('notificationclick', event => {
  event.notification.close();
  const pagina = (event.notification.data && event.notification.data.pagina) || 'painel';
  const destino = self.registration.scope + '?ir=' + pagina;

  event.waitUntil(clients.matchAll({ type: 'window', includeUncontrolled: true }).then(lista => {
    for (const c of lista) {
      if (c.url.startsWith(self.registration.scope) && 'focus' in c) {
        c.postMessage({ tipo: 'ir', pagina });
        return c.focus();
      }
    }
    return clients.openWindow(destino);
  }));
});
