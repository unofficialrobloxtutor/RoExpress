/* RoExpress Docs — shared navigation, search, and UI
   Pages at /docs/index.html use: css/styles.css  nav.js
   Pages at /docs/pages/*.html use: ../css/styles.css  ../nav.js
*/
(function () {
  const BASE = '/docs';
  const P    = BASE + '/pages/';   // flat page directory

  // ── Active page detection ────────────────────────────────────────────
  function activeId() {
    const raw = window.location.pathname.replace(/\/$/, '');
    if (raw === BASE || raw === BASE + '/index.html' || raw === '' || raw === '/') return 'overview';
    // For /docs/pages/app.html → 'app'
    const file = raw.split('/').pop();
    return file.replace(/\.html$/, '') || 'overview';
  }
  const ACTIVE = activeId();

  // ── Nav link builder ─────────────────────────────────────────────────
  function nl(href, id, label, badge) {
    const cls = ACTIVE === id ? 'nl active' : 'nl';
    return `<a class="${cls}" href="${href}">${label}${badge || ''}</a>`;
  }
  function nb(text, style) {
    return ` <span class="nb"${style ? ` style="${style}"` : ''}>${text}</span>`;
  }

  // ── Sidebar ──────────────────────────────────────────────────────────
  const SIDEBAR = `
    <div class="ns">
      <button class="nsh open" onclick="tn(this)">Getting Started <span class="chv">▶</span></button>
      <div class="ni open">
        ${nl(BASE + '/', 'overview', 'Overview')}
        ${nl(P + 'installation.html', 'installation', 'Installation')}
        ${nl(BASE + '/#quickstart', 'quickstart', 'Quick Start')}
        ${nl(P + 'accessors.html', 'accessors', 'Module Accessors')}
        ${nl(P + 'pipeline.html', 'pipeline', 'Request Pipeline')}
        ${nl(P + 'roadmap.html',  'roadmap',  'Roadmap' + nb('2.4+', 'background:#b45309;color:#fef3c7'))}
      </div>
    </div>
    <div class="ns">
      <button class="nsh open" onclick="tn(this)">Server API <span class="chv">▶</span></button>
      <div class="ni open">
        ${nl(P + 'app.html',       'app',       'App')}
        ${nl(P + 'broadcast.html', 'broadcast', 'Broadcast')}
        ${nl(P + 'tamper.html',    'tamper',    'Tamper')}
        ${nl(P + 'harpy.html',     'harpy',     'Harpy' + nb('new', 'background:var(--accent-bg);color:var(--accent2)'))}
      </div>
    </div>
    <div class="ns">
      <button class="nsh open" onclick="tn(this)">Client API <span class="chv">▶</span></button>
      <div class="ni open">
        ${nl(P + 'network.html',   'network',   'Network')}
        ${nl(P + 'listener.html',  'listener',  'Listener')}
        ${nl(P + 'benchmark.html', 'benchmark', 'Benchmark')}
      </div>
    </div>
    <div class="ns">
      <button class="nsh open" onclick="tn(this)">New in v2 <span class="chv">▶</span></button>
      <div class="ni open">
        ${nl(P + 'router.html',      'router',      'Router'    + nb('v2'))}
        ${nl(P + 'push.html',        'push',        'Server Push' + nb('v2'))}
        ${nl(P + 'codec.html',       'codec',       'Codec'     + nb('v2'))}
        ${nl(P + 'bridge.html',      'bridge',      'Bridge'    + nb('v2'))}
        ${nl(P + 'port.html',        'port',        'Ports'     + nb('v2'))}
        ${nl(P + 'stream.html',      'stream',      'Stream'    + nb('v2.4', 'background:#b45309;color:#fef3c7'))}
        ${nl(P + 'typecoercer.html', 'typecoercer', 'TypeCoercer' + nb('v2.2'))}
        ${nl(P + 'promise.html',     'promise',     'Promise'   + nb('v2.2'))}
      </div>
    </div>
    <div class="ns">
      <button class="nsh open" onclick="tn(this)">Shared <span class="chv">▶</span></button>
      <div class="ni open">
        ${nl(P + 'tokenbucket.html', 'tokenbucket', 'TokenBucket')}
        ${nl(P + 'base64.html',      'base64',      'Base64')}
        ${nl(P + 'types.html',       'types',       'Types')}
      </div>
    </div>
    <div class="ns">
      <button class="nsh open" onclick="tn(this)">Examples <span class="chv">▶</span></button>
      <div class="ni open">
        ${nl(P + 'ex-killfeed.html',  'ex-killfeed',  'Kill Feed')}
        ${nl(P + 'ex-round.html',     'ex-round',     'Round Manager')}
        ${nl(P + 'ex-shop.html',      'ex-shop',      'Shop / Purchase')}
        ${nl(P + 'ex-admin.html',     'ex-admin',     'Admin Commands')}
        ${nl(P + 'ex-friendzone.html','ex-friendzone','Friend Zone')}
        ${nl(P + 'ex-leaderboard.html','ex-leaderboard','Leaderboard')}
        ${nl(P + 'ex-playerdata.html','ex-playerdata', 'Player Data')}
        ${nl(P + 'ex-matchmaking.html','ex-matchmaking','Matchmaking')}
        ${nl(P + 'examples-gun.html', 'examples-gun',  'Gun Framework' + nb('new', 'background:var(--accent-bg);color:var(--accent2)'))}
        ${nl(P + 'examples-inventory.html','examples-inventory','Inventory System' + nb('new', 'background:var(--accent-bg);color:var(--accent2)'))}
        ${nl(P + 'examples-streaming.html','examples-streaming','Live Streaming'   + nb('new', 'background:var(--accent-bg);color:var(--accent2)'))}
      </div>
    </div>
    <div class="ns">
      <button class="nsh open" onclick="tn(this)">Guides <span class="chv">▶</span></button>
      <div class="ni open">
        ${nl(P + 'guide-middleware.html', 'guide-middleware', 'Middleware')}
        ${nl(P + 'guide-mvc.html',        'guide-mvc',        'MVC Pattern')}
        ${nl(P + 'guide-routes.html',     'guide-routes',     'Route Organisation')}
        ${nl(P + 'guide-promise.html',    'guide-promise',    'Promise')}
        ${nl(P + 'guide-typecoercer.html','guide-typecoercer','TypeCoercer')}
        ${nl(P + 'guide-stream.html',     'guide-stream',     'FPS Stream')}
        ${nl(P + 'guide-ports.html',      'guide-ports',      'Ports')}
        ${nl(P + 'guide-tamper.html',     'guide-tamper',     'Exploit Detection')}
        ${nl(P + 'guides-auth.html',      'guides-auth',      'Authentication'   + nb('new', 'background:var(--accent-bg);color:var(--accent2)'))}
        ${nl(P + 'guides-combat.html',    'guides-combat',    'Combat System'    + nb('new', 'background:var(--accent-bg);color:var(--accent2)'))}
        ${nl(P + 'guides-migration.html', 'guides-migration', 'Migration v2.3→2.4' + nb('new', 'background:var(--accent-bg);color:var(--accent2)'))}
      </div>
    </div>
    <div class="ns">
      <button class="nsh open" onclick="tn(this)">Community <span class="chv">▶</span></button>
      <div class="ni open">
        ${nl(P + 'community-discord.html', 'community-discord', '◈ Discord')}
        ${nl(P + 'community-github.html',  'community-github',  '⌥ GitHub')}
        ${nl(P + 'community-twitter.html', 'community-twitter', '𝕏 Twitter')}
        ${nl(P + 'community-website.html', 'community-website', '🌐 Website')}
        ${nl(P + 'youtube.html',           'youtube',           '▶ YouTube')}
        ${nl(P + 'support.html',           'support',           'Support ♥')}
      </div>
    </div>
    <div class="ns">
      <button class="nsh open" onclick="tn(this)">Reference <span class="chv">▶</span></button>
      <div class="ni open">
        ${nl(P + 'comparison.html',       'comparison',       'Comparison')}
        ${nl(P + 'design-consensus.html', 'design-consensus', 'Design Consensus')}
        ${nl(P + 'story.html',            'story',            'The Story ✦')}
        ${nl(P + 'updates.html',          'updates',          'Updates' + nb('v2.4', 'background:#b45309;color:#fef3c7'))}
        ${nl(P + 'research.html',         'research',         'Research Papers')}
        ${nl(P + 'changelog.html',        'changelog',        'Changelog')}
        ${nl(P + 'reference.html',        'reference',        'API Reference')}
      </div>
    </div>`;

  // ── Header ────────────────────────────────────────────────────────────
  const HEADER = `
    <button id="burger" onclick="toggleSidebar()" aria-label="Toggle navigation">☰</button>
    <a class="logo" href="/">
      <svg width="30" height="30" viewBox="80 120 148 148" xmlns="http://www.w3.org/2000/svg" style="flex-shrink:0;border-radius:7px">
        <rect x="80" y="120" width="148" height="148" rx="30" fill="#a594ff"/>
        <rect x="104" y="158" width="100" height="9" rx="4.5" fill="#0d0d1f"/>
        <rect x="104" y="217" width="100" height="9" rx="4.5" fill="#0d0d1f"/>
        <rect x="104" y="158" width="9" height="68" rx="4.5" fill="#0d0d1f"/>
        <rect x="152" y="167" width="9" height="30" rx="4.5" fill="#0d0d1f"/>
        <circle cx="156" cy="162" r="7" fill="#0d0d1f"/>
        <circle cx="156" cy="222" r="7" fill="#0d0d1f"/>
        <circle cx="204" cy="162" r="7" fill="#0d0d1f"/>
        <circle cx="204" cy="222" r="7" fill="#0d0d1f"/>
      </svg>
      <span class="logo-name">RoExpress</span>
      <span class="logo-ver">v2.4</span>
    </a>
    <div id="sw">
      <span class="sico">⌕</span>
      <input id="si" type="text" placeholder="Search docs…" autocomplete="off" spellcheck="false">
      <div id="sr"></div>
    </div>
    <div class="hright">
      <button id="tgl" title="Toggle theme" onclick="toggleTheme()">☽</button>
    </div>`;

  // ── Search index ──────────────────────────────────────────────────────
  const IDX = [
    { s:'overview',    url:BASE+'/',                        t:'guide',   n:'Overview',             x:'structured networking roblox pipeline module tree install' },
    { s:'pipeline',    url:P+'pipeline.html',               t:'ref',     n:'Request Pipeline',     x:'version tokenbucket validate middleware route 400 403 404 429 500' },
    { s:'installation',url:P+'installation.html',            t:'guide',   n:'Installation',         x:'install command bar wally manual creator store insertservice loadasset studio setup' },
    { s:'accessors',   url:P+'accessors.html',               t:'guide',   n:'Module Accessors',     x:'getapp getnetwork accessor typed call form property port name cache context any' },
    { s:'roadmap',     url:P+'roadmap.html',                t:'guide',   n:'Roadmap',              x:'next planned future retry compact deflate stream overhaul typing youtube' },
    { s:'app',         url:P+'app.html',                    t:'api',     n:'App',                  x:'get post put delete use unuse push pushall req res send error status compress' },
    { s:'broadcast',   url:P+'broadcast.html',              t:'api',     n:'Broadcast',            x:'emit emitall emitto unreliable 900 bytes' },
    { s:'tamper',      url:P+'tamper.html',                 t:'api',     n:'Tamper',               x:'exploit detection strike autokick version spoof malformed payload rate flood' },
    { s:'harpy',       url:P+'harpy.html',                  t:'api',     n:'Harpy',                x:'http outbound httpclient requestasync get post put delete webhook retry backoff base url headers' },
    { s:'network',     url:P+'network.html',                t:'api',     n:'Network',              x:'get post put delete cancel timeout networkresponse callback promise async' },
    { s:'listener',    url:P+'listener.html',               t:'api',     n:'Listener',             x:'on once off use unuse push broadcast dual channel reliable unreliable' },
    { s:'benchmark',   url:P+'benchmark.html',              t:'api',     n:'Benchmark',            x:'run print compare latency p95 p99 throughput rtt warmup' },
    { s:'router',      url:P+'router.html',                 t:'api',     n:'Router',               x:'typed param wildcard glob constraint number boolean vector2 vector3 cframe captures' },
    { s:'push',        url:P+'push.html',                   t:'api',     n:'Server Push',          x:'push pushall pushto reliable server initiated listener event' },
    { s:'codec',       url:P+'codec.html',                  t:'api',     n:'Codec',                x:'lz77 lzh deflate compress decompress iscompressed buffer' },
    { s:'bridge',      url:P+'bridge.html',                 t:'api',     n:'Bridge',               x:'bind unbind fire has wait waituntil waitfirst yield coroutine bus' },
    { s:'port',        url:P+'port.html',                   t:'api',     n:'Ports',                x:'listen port isolated pipeline named remoteevent combat inventory' },
    { s:'stream',      url:P+'stream.html',                 t:'api',     n:'Stream',               x:'schema channel binary buffer vector3 cframe delta compression sequence unreliable' },
    { s:'typecoercer', url:P+'typecoercer.html',            t:'api',     n:'TypeCoercer',          x:'coerce number int boolean vector2 vector3 cframe color3 enum instance param' },
    { s:'promise',     url:P+'promise.html',                t:'api',     n:'Promise',              x:'then catch finally resolve reject async chain getasync postasync' },
    { s:'tokenbucket', url:P+'tokenbucket.html',            t:'api',     n:'TokenBucket',          x:'consume hastokens grant grantall reset destroy max refill rate limit' },
    { s:'base64',      url:P+'base64.html',                 t:'api',     n:'Base64',               x:'encode decode encodetable decodetable json' },
    { s:'types',       url:P+'types.html',                  t:'ref',     n:'Types',                x:'payload request response networkresponse routehandler middlewarehandler' },
    { s:'ex-killfeed', url:P+'ex-killfeed.html',            t:'example', n:'Kill Feed',            x:'push broadcast bridge compress typed params wildcard' },
    { s:'ex-round',    url:P+'ex-round.html',               t:'example', n:'Round Manager',        x:'broadcast push bridge countdown round start end timer' },
    { s:'ex-shop',     url:P+'ex-shop.html',                t:'example', n:'Shop / Purchase',      x:'buy sell currency stock validate push inventory' },
    { s:'ex-admin',    url:P+'ex-admin.html',               t:'example', n:'Admin Commands',       x:'middleware kick ban god mode announce admin role' },
    { s:'ex-friendzone',url:P+'ex-friendzone.html',         t:'example', n:'Friend Zone',          x:'zone proximity push enter exit server loop position' },
    { s:'ex-leaderboard',url:P+'ex-leaderboard.html',       t:'example', n:'Leaderboard',          x:'rank score top paginated compress push update' },
    { s:'ex-playerdata',url:P+'ex-playerdata.html',         t:'example', n:'Player Data',          x:'datastore save load push bridge ready join' },
    { s:'ex-matchmaking',url:P+'ex-matchmaking.html',       t:'example', n:'Matchmaking Queue',    x:'queue join leave pushto match ready bridge players' },
    { s:'guide-middleware',url:P+'guide-middleware.html',   t:'guide',   n:'Middleware Guide',     x:'use unuse order chain middleware pipeline auth logging ban' },
    { s:'guide-mvc',   url:P+'guide-mvc.html',              t:'guide',   n:'MVC Pattern',          x:'model view controller pattern service architecture decouple' },
    { s:'guide-promise',url:P+'guide-promise.html',         t:'guide',   n:'Promise Guide',        x:'then catch chain async await promise resolve reject' },
    { s:'guide-typecoercer',url:P+'guide-typecoercer.html', t:'guide',   n:'TypeCoercer Guide',    x:'typed params coerce number int enum instance custom' },
    { s:'guide-stream',url:P+'guide-stream.html',           t:'guide',   n:'FPS Stream Guide',     x:'fps stream shooting hit validation lag compensation movement' },
    { s:'guide-ports', url:P+'guide-ports.html',            t:'guide',   n:'Ports Guide',          x:'ports isolated pipeline named rate limit separate channel' },
    { s:'guide-tamper',url:P+'guide-tamper.html',           t:'guide',   n:'Exploit Detection',    x:'exploit tamper detection strike autokick version spoof' },
    { s:'guides-auth', url:P+'guides-auth.html',            t:'guide',   n:'Authentication',       x:'auth middleware role permission whitelist banlist 403' },
    { s:'guides-combat',url:P+'guides-combat.html',         t:'guide',   n:'Combat System',        x:'gun shoot hit damage port stream broadcast tokenbucket' },
    { s:'guides-migration',url:P+'guides-migration.html',  t:'guide',   n:'Migration v2.3→2.4',   x:'upgrade breaking stream v2.4 typed accessor compact handler' },
    { s:'community-discord',url:P+'community-discord.html',t:'community',n:'Discord',             x:'discord chat community help server channel' },
    { s:'community-github',url:P+'community-github.html',  t:'community',n:'GitHub',              x:'github issues pull request contribute source code' },
    { s:'youtube',     url:P+'youtube.html',                t:'community',n:'YouTube',             x:'youtube video tutorial walkthrough gun framework showcase' },
    { s:'support',     url:P+'support.html',                t:'community',n:'Support',             x:'support donate sponsor patreon' },
    { s:'comparison',  url:P+'comparison.html',             t:'ref',     n:'Comparison',           x:'comparison remote event remotefunction other frameworks versus' },
    { s:'story',       url:P+'story.html',                  t:'ref',     n:'The Story',            x:'story history origin why made motivation design' },
    { s:'updates',     url:P+'updates.html',                t:'ref',     n:'Updates',              x:'updates changelog v2.4 v2.3 release notes' },
    { s:'changelog',   url:P+'changelog.html',              t:'ref',     n:'Changelog',            x:'changelog version history added changed removed breaking' },
    { s:'reference',   url:P+'reference.html',              t:'ref',     n:'API Reference',        x:'reference overview api index types pipeline' },
    { s:'examples-gun',url:P+'examples-gun.html',           t:'example', n:'Gun Framework',        x:'gun shoot hit damage replication health player combat port stream' },
  ];

  // ── DOM ready ─────────────────────────────────────────────────────────
  document.addEventListener('DOMContentLoaded', function () {
    const hdr = document.getElementById('hdr');
    if (hdr) hdr.innerHTML = HEADER;
    const sb = document.getElementById('sb');
    if (sb) sb.innerHTML = SIDEBAR;

    // Search
    const si = document.getElementById('si');
    const sr = document.getElementById('sr');
    if (!si || !sr) return;
    let ai = -1;

    si.addEventListener('input', () => {
      const q = si.value.trim().toLowerCase();
      if (!q) { sr.style.display = 'none'; return; }
      const hits = IDX.filter(x => x.n.toLowerCase().includes(q) || x.x.includes(q)).slice(0, 9);
      if (!hits.length) { sr.style.display = 'none'; return; }
      ai = -1;
      sr.innerHTML = hits.map((h, i) =>
        `<div class="sri" data-url="${h.url}" data-i="${i}"><span class="sri-tag">${h.t}</span><span class="sri-title">${h.n}</span></div>`
      ).join('');
      sr.style.display = 'block';
      sr.querySelectorAll('.sri').forEach(el => el.addEventListener('click', () => { window.location.href = el.dataset.url; }));
    });

    si.addEventListener('keydown', e => {
      const items = sr.querySelectorAll('.sri');
      if (e.key === 'ArrowDown') { e.preventDefault(); ai = Math.min(ai + 1, items.length - 1); updAi(items); }
      else if (e.key === 'ArrowUp') { e.preventDefault(); ai = Math.max(ai - 1, 0); updAi(items); }
      else if (e.key === 'Enter' && ai >= 0) items[ai].click();
      else if (e.key === 'Escape') { sr.style.display = 'none'; si.blur(); }
    });
    function updAi(items) { items.forEach((el, i) => el.classList.toggle('act', i === ai)); }
    document.addEventListener('click', e => { if (!e.target.closest('#sw')) sr.style.display = 'none'; });

    // Back to top
    const btt = document.getElementById('btt');
    window.addEventListener('scroll', () => { if (btt) btt.classList.toggle('show', window.scrollY > 300); }, { passive: true });

    // Copy buttons
    document.querySelectorAll('.cb').forEach(btn => {
      btn.addEventListener('click', () => {
        navigator.clipboard.writeText(btn.nextElementSibling.innerText).then(() => {
          btn.textContent = 'copied!'; btn.classList.add('ok');
          setTimeout(() => { btn.textContent = 'copy'; btn.classList.remove('ok'); }, 1800);
        });
      });
    });

    // Checkmark colours
    document.querySelectorAll('.tbl td').forEach(td => {
      td.innerHTML = td.innerHTML
        .replace(/✓/g, '<span style="color:#4ade80;font-weight:600">✓</span>')
        .replace(/✗/g, '<span style="color:#f87171">✗</span>');
    });
  });

  // Global helpers
  window.tn = function (btn) { btn.classList.toggle('open'); btn.nextElementSibling.classList.toggle('open'); };
  window.toggleTheme = function () {
    const b = document.body, d = b.dataset.theme === 'dark';
    b.dataset.theme = d ? 'light' : 'dark';
    const tgl = document.getElementById('tgl');
    if (tgl) tgl.textContent = d ? '☀' : '☽';
  };
  window.toggleSidebar = function () {
    const sb = document.getElementById('sb'), ov = document.getElementById('overlay');
    if (sb) sb.classList.toggle('open');
    if (ov) ov.classList.toggle('open');
  };
  window.cp = function (btn) {
    navigator.clipboard.writeText(btn.nextElementSibling.innerText).then(() => {
      btn.textContent = 'copied!'; btn.classList.add('ok');
      setTimeout(() => { btn.textContent = 'copy'; btn.classList.remove('ok'); }, 1800);
    });
  };
})();
