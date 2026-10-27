// Pruebas de la lógica pura de la conexión con doro.page (Supabase.js). Correr con: node tests/supabase.test.mjs
// Supabase.js es un script de QML (`.pragma library`), así que se evalúa a mano en vez de importarlo.
import fs from "node:fs"; import assert from "node:assert/strict";
const src = fs.readFileSync(new URL("../Supabase.js", import.meta.url), "utf8").replace(".pragma library", "");
const S = new Function(src + "; return {URL_PROYECTO, ANON_KEY, configuracion, urlEntrar, urlVincular, parsearRetorno, sesionGuardada, sesionVencida, pendientesGuardados, agregarPendiente, filasSesiones, sacarPendientes, resumen, fechaLocal};")();

let c = S.configuracion('{"url":"https://x.supabase.co/","anonKey":"k"}'); assert.deepEqual(c, { url: "https://x.supabase.co", anonKey: "k" });
assert.deepEqual(S.configuracion("basura{"), { url: S.URL_PROYECTO, anonKey: S.ANON_KEY });
assert.equal(S.urlEntrar("https://x", "github"), "https://x/auth/v1/authorize?provider=github&redirect_to=doro%3A%2F%2Fauth");
assert.ok(S.urlVincular("", "google").startsWith("/auth/v1/user/identities/authorize?provider=google&") && S.urlVincular("", "google").endsWith("&skip_http_redirect=true"));

const ahora = 1_000_000_000_000;
let r = S.parsearRetorno("doro://auth#access_token=a%2Eb&expires_in=3600&refresh_token=r&token_type=bearer", ahora);
assert.deepEqual(r.tokens, { access_token: "a.b", refresh_token: "r", expires_at: ahora + 3600_000, usuario: null });
r = S.parsearRetorno("doro://auth#access_token=a&refresh_token=r&expires_at=2000000000", ahora); assert.equal(r.tokens.expires_at, 2_000_000_000_000);
r = S.parsearRetorno("doro://auth?error=server_error&error_code=identity_already_exists&error_description=Identity+is+already+linked", ahora);
assert.deepEqual(r, { error: "Identity is already linked", codigo: "identity_already_exists" });
r = S.parsearRetorno("doro://auth/#error=access_denied", ahora); assert.equal(r.error, "access_denied");
assert.equal(S.parsearRetorno("https://evil/#access_token=a&refresh_token=r", ahora).codigo, "retorno_invalido");
assert.equal(S.parsearRetorno("doro://auth#access_token=a", ahora).codigo, "faltan_tokens");
assert.deepEqual(S.parsearRetorno("doro://auth#error=access_denied", ahora), { error: "access_denied", codigo: "error" });

assert.equal(S.sesionGuardada("null"), null); assert.equal(S.sesionGuardada('{"access_token":1}'), null);
const s = S.sesionGuardada('{"access_token":"a","refresh_token":"r","expires_at":5000,"usuario":{"id":"u","anonimo":true}}');
assert.equal(s.usuario.id, "u");
assert.ok(S.sesionVencida(null, 0)); assert.ok(S.sesionVencida(s, 0)); assert.ok(!S.sesionVencida({ expires_at: 120_000 }, 0));

let p = S.pendientesGuardados('[{"duration_minutes":25,"created_at":"2026-10-27T12:00:00.000Z"},{"duration_minutes":0,"created_at":"x"},null]');
assert.equal(p.length, 1);
p = S.agregarPendiente(p, 50, new Date("2026-10-27T13:00:00Z")); assert.equal(p.length, 2);
assert.deepEqual(S.filasSesiones(p, "u")[1], { user_id: "u", duration_minutes: 50, created_at: "2026-10-27T13:00:00.000Z" });
assert.deepEqual(S.sacarPendientes(p, 1), [p[1]]); assert.deepEqual(S.pendientesGuardados("{}"), []);

const hoy = new Date(2026, 9, 27, 10);
assert.equal(S.fechaLocal(hoy), "2026-10-27");
const daily = { daily: [{ stat_date: "2026-10-26", total_minutes: 50 }, { stat_date: "2026-10-27", total_minutes: 75 }] };
assert.deepEqual(S.resumen({ current_streak: 3, last_study_date: "2026-10-27" }, daily, hoy), { hoy: 75, racha: 3 });
assert.deepEqual(S.resumen({ current_streak: 3, last_study_date: "2026-10-26" }, { daily: [] }, hoy), { hoy: 0, racha: 3 });
assert.deepEqual(S.resumen({ current_streak: 3, last_study_date: "2026-10-25" }, null, hoy), { hoy: 0, racha: 0 });
assert.deepEqual(S.resumen(undefined, daily, hoy), { hoy: 75, racha: 0 });
console.log("Supabase.js: todo OK");

// El .env del plugin
const E = new Function(src + "; return {leerEnv, configuracionEnv, configuracion};")();
assert.deepEqual(E.leerEnv('# c\nexport A="x y"\nB = z # nota\nC=\'q\'\nmal linea\n'), { A: "x y", B: "z", C: "q" });
const env = E.configuracionEnv("DORO_SUPABASE_URL=https://e.supabase.co/\nDORO_SUPABASE_ANON_KEY=ke\n");
assert.deepEqual(env, { url: "https://e.supabase.co", anonKey: "ke" });
assert.deepEqual(E.configuracion('{"anonKey":"kj"}', env), { url: "https://e.supabase.co", anonKey: "kj" });
assert.deepEqual(E.configuracion("", env), env);
console.log("Supabase.js (.env): todo OK");
// El .env.example sin completar no pisa las constantes.
assert.deepEqual(E.configuracionEnv(fs.readFileSync(new URL("../.env.example", import.meta.url), "utf8")), E.configuracion(""));
