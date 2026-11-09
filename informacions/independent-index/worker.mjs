/**
 * INFORMACIONS.AD / ANDORRA 24 — índice editorial desacoplado de Sites/Work.
 * Solo endpoints de ENSAYO: /_a24/health, /_a24/index.json y /_a24/preview.
 * Ninguna ruta de producción se intercepta con este código.
 */
const SOURCE = "https://informacions.ad";
const LANGUAGES = ["ca", "es", "fr", "en"];
const SLOT_ORDER = { nit: 4, tarda: 3, migdia: 2, mati: 1, especial: 0 };
const SLOT_NAMES = {
  ca: { mati: "MATÍ", migdia: "MIGDIA", tarda: "TARDA", nit: "NIT", especial: "ESPECIAL" },
  es: { mati: "MAÑANA", migdia: "MEDIODÍA", tarda: "TARDE", nit: "NOCHE", especial: "ESPECIAL" },
  fr: { mati: "MATIN", migdia: "MIDI", tarda: "APRÈS-MIDI", nit: "NUIT", especial: "SPÉCIAL" },
  en: { mati: "MORNING", migdia: "MIDDAY", tarda: "AFTERNOON", nit: "NIGHT", especial: "SPECIAL" }
};
const HEADINGS = { ca: "ANDORRA 24 · LES NOTÍCIES DEL DIA", es: "ANDORRA 24 · LAS NOTICIAS DEL DÍA", fr: "ANDORRA 24 · LES INFORMATIONS DU JOUR", en: "ANDORRA 24 · TODAY'S NEWS" };
const VIEW = { ca: "Llegir l’edició", es: "Leer la edición", fr: "Lire l’édition", en: "Read the edition" };
const xmlDecode = (s) => s.replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&apos;/g, "'");
const htmlEscape = (s) => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#39;");

export function parseAndorra24Urls(xml) {
  if (typeof xml !== "string" || xml.length > 3000000) throw Error("Sitemap XML invalid or too large");
  const map = new Map();
  for (const m of xml.matchAll(/<loc(?:\s[^>]*)?>\s*([^<]+)\s*<\/loc>/gi)) {
    let parsed;
    try { parsed = new URL(xmlDecode(m[1].trim())); } catch { continue; }
    if (parsed.origin !== SOURCE) continue;
    const match = /^\/(ca|es|fr|en)\/article\/(andorra24-(\d{4}-\d{2}-\d{2})-(.+)-(ca|es|fr|en))\/?$/i.exec(parsed.pathname);
    if (!match || match[1].toLowerCase() !== match[5].toLowerCase()) continue;
    const locale = match[1].toLowerCase();
    const slug = match[2];
    const date = match[3];
    if (!Number.isFinite(Date.parse(date + "T12:00:00Z"))) continue;
    const stem = slug.replace(/-(ca|es|fr|en)$/i, "");
    const slotMatch = /(?:^|-)(mati|migdia|tarda|nit|especial)(?:-|$)/i.exec(stem);
    const slot = slotMatch ? slotMatch[1].toLowerCase() : null;
    const path = parsed.pathname.replace(/\/$/, "");
    map.set(path, { locale, date, slug, canonicalId: stem, slot, url: SOURCE + path });
  }
  return [...map.values()].sort((a, b) =>
    b.date.localeCompare(a.date) ||
    (SLOT_ORDER[b.slot] || 0) - (SLOT_ORDER[a.slot] || 0) ||
    a.canonicalId.localeCompare(b.canonicalId) ||
    a.locale.localeCompare(b.locale));
}

function articleMeta(html) {
  let title = "";
  let publishedAt = null;
  for (const tag of html.matchAll(/<meta\b[^>]*>/gi)) {
    const attrs = {};
    for (const attr of tag[0].matchAll(/([\w:-]+)\s*=\s*(["'])(.*?)\2/g)) attrs[attr[1].toLowerCase()] = attr[3];
    const key = (attrs.property || attrs.name || "").toLowerCase();
    if (key === "og:title" && attrs.content) title = xmlDecode(attrs.content);
    if ((key === "article:published_time" || key === "datepublished") && attrs.content) publishedAt = attrs.content;
  }
  if (!title) {
    const t = /<title[^>]*>([\s\S]*?)<\/title>/i.exec(html);
    if (t) title = xmlDecode(t[1].replace(/<[^>]+>/g, "").trim()).replace(/\s*[|·]\s*INFORMACIONS.*$/i, "");
  }
  title = title.trim().slice(0, 220);
  return { title: title || null, publishedAt };
}

async function fetchSitemap() {
  // No se aceptan URLs arbitrarias ni redirecciones a hosts ajenos.
  const res = await fetch(SOURCE + "/sitemap.xml", { redirect: "manual", headers: { Accept: "application/xml, text/xml" } });
  if (!res.ok || !(res.headers.get("content-type") || "").match(/xml|text\/plain/)) throw Error("Sitemap unavailable");
  const xml = await res.text();
  if (xml.length > 3000000) throw Error("Sitemap too large");
  return xml;
}

async function enrich(items) {
  // Límite estricto de solicitudes de origen. Los títulos ausentes NO se inventan.
  const selected = items.slice(0, 12);
  const output = [];
  for (let i = 0; i < selected.length; i += 4) {
    const batch = await Promise.all(selected.slice(i, i + 4).map(async (item) => {
      try {
        const res = await fetch(item.url, { redirect: "manual", headers: { Accept: "text/html" } });
        if (!res.ok || !(res.headers.get("content-type") || "").includes("text/html")) return { ...item, verified: false, title: null };
        const meta = articleMeta(await res.text());
        return { ...item, ...meta, verified: true };
      } catch { return { ...item, verified: false, title: null }; }
    }));
    output.push(...batch);
  }
  return output;
}

async function indexFor(locale) {
  const urls = parseAndorra24Urls(await fetchSitemap());
  // Nunca mostrar otra lengua como si fuera una traducción.
  const matches = urls.filter((x) => x.locale === locale);
  if (matches.length === 0) throw Error("No verified locale records in sitemap");
  const latest = await enrich(matches);
  return {
    source: SOURCE + "/sitemap.xml",
    generatedAt: new Date().toISOString(),
    locale,
    total: matches.length,
    latest,
    // URL de todas las ediciones, incluso las antiguas; sin duplicarlas.
    archive: matches
  };
}

function previewHtml(data) {
  const lang = data.locale;
  const cards = data.latest.map((r) => {
    const line = r.slot ? SLOT_NAMES[lang][r.slot] : "ANDORRA 24";
    const headline = r.title || ("ANDORRA 24 · " + r.date);
    return '<article class="edition"><small>' + htmlEscape(r.date) + ' · ' + htmlEscape(line) +
      '</small><h2>' + htmlEscape(headline) + '</h2><a href="' + htmlEscape(r.url) +
      '" rel="noopener">' + VIEW[lang] + '</a></article>';
  }).join("");
  const nav = LANGUAGES.map((l) => '<a href="/_a24/preview?lang=' + l + '" hreflang="' + l + '">' + l.toUpperCase() + '</a>').join(" · ");
  return '<!doctype html><html lang="' + lang + '"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="robots" content="noindex,nofollow"><title>' +
    HEADINGS[lang] + ' (assaig)</title><style>body{font:16px system-ui;background:#080808;color:white;max-width:850px;margin:auto;padding:24px}a{color:#fff}.edition{padding:20px 0;border-bottom:1px solid #555}small{color:#bbb}h2{font-size:22px}header{border-bottom:2px solid #aaa;padding-bottom:14px}</style></head><body><header><p>ENTORNO D’ASSAIG · NO PUBLICAT A INFORMACIONS.AD</p><nav>' +
    nav + '</nav><h1>' + HEADINGS[lang] + '</h1><p>Índex de només lectura · ' + data.total +
    ' URL del sitemap en aquest idioma</p></header><main>' + cards +
    '</main><footer><p>Els títols no disponibles es mostren com a edició genèrica, mai inventats.</p></footer></body></html>';
}

export default {
  async fetch(request) {
    const url = new URL(request.url);
    if (request.method !== "GET" && request.method !== "HEAD") return new Response("Method not allowed", { status: 405 });
    if (url.pathname === "/_a24/health") return Response.json({ status: "staging_only", modifiesProduction: false });
    if (url.pathname !== "/_a24/index.json" && url.pathname !== "/_a24/preview") return new Response("Not found: staging routes only", { status: 404 });
    const locale = (url.searchParams.get("lang") || "ca").toLowerCase();
    if (!LANGUAGES.includes(locale)) return new Response("Invalid locale", { status: 400 });
    try {
      const data = await indexFor(locale);
      const headers = { "Cache-Control": "public, max-age=60, s-maxage=120", "X-Robots-Tag": "noindex" };
      return url.pathname.endsWith(".json")
        ? Response.json(data, { headers })
        : new Response(previewHtml(data), { headers: { ...headers, "Content-Type": "text/html; charset=utf-8" } });
    } catch (e) {
      // Error cerrado: nunca sustituir contenido vivo por un archivo vacío.
      return Response.json({ error: "INDEX_UNAVAILABLE", message: String(e.message) }, { status: 503, headers: { "Cache-Control": "no-store" } });
    }
  }
};
