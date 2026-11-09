import test from "node:test";
import assert from "node:assert/strict";
import { parseAndorra24Urls } from "./worker.mjs";

const months = ["2026-11-07", "2026-11-08"];
const slots = ["mati", "migdia", "tarda", "nit"];
const languages = ["ca", "es", "fr", "en"];
const locations = months.flatMap((date) => slots.flatMap((slot) => languages.map((locale) =>
  "https://informacions.ad/" + locale + "/article/andorra24-" + date + "-" + slot + "-abcdef123456-" + locale)));
const xml = '<?xml version="1.0"?><urlset>' + locations.map((u) => "<url><loc>" + u + "</loc></url>").join("") +
  '<url><loc>https://informacions.ad/ca/article/andorra24-2026-11-08-nit-abcdef123456-ca</loc></url>' +
  '<url><loc>https://malicious.example/ca/article/andorra24-2026-11-09-mati-a-ca</loc></url>' +
  '<url><loc>https://informacions.ad/ca/article/andorra24-2026-11-08-nit-abcdef123456-en</loc></url>' +
  '</urlset>';

test("32 URLs reales: cuatro franjas por cuatro idiomas y dos días", () => {
  const rows = parseAndorra24Urls(xml);
  assert.equal(rows.length, 32);
  for (const locale of languages) assert.equal(rows.filter((x) => x.locale === locale).length, 8);
});
test("orden fecha / franja: NIT del 8 antes que TARDA del 8 y el 7", () => {
  const ca = parseAndorra24Urls(xml).filter((x) => x.locale === "ca");
  assert.equal(ca[0].date, "2026-11-08");
  assert.equal(ca[0].slot, "nit");
  assert.equal(ca[1].slot, "tarda");
  assert.equal(ca[4].date, "2026-11-07");
});
test("deduplicación exacta, solo host propio, no mezclar locale", () => {
  const rows = parseAndorra24Urls(xml);
  assert.equal(new Set(rows.map((x) => x.url)).size, 32);
  assert.ok(rows.every((x) => x.url.startsWith("https://informacions.ad/")));
  assert.ok(rows.every((x) => x.url.endsWith("-" + x.locale)));
});
test("rechazar XML excesivo y entradas sin validez", () => {
  assert.throws(() => parseAndorra24Urls("x".repeat(3000001)));
  assert.deepEqual(parseAndorra24Urls("<urlset></urlset>"), []);
});
