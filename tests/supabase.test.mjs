// Pruebas de la lógica pura de la conexión con doro.page (Supabase.js). Correr con: node tests/supabase.test.mjs
// Supabase.js es un script de QML (`.pragma library`), así que se evalúa a mano en vez de importarlo.
import fs from "node:fs"; import assert from "node:assert/strict"; import crypto from "node:crypto";
const src = fs.readFileSync(new URL("../Supabase.js", import.meta.url), "utf8").replace(".pragma library", "");
const S = new Function(src + "; return {URL_PROYECTO, ANON_KEY, configuracion, verificadorDesde, desafio, sha256, canjePkce, urlEntrar, urlVincular, parsearRetorno, sesionDesdeRespuesta, sesionGuardada, sesionVencida, pendientesGuardados, agregarPendiente, filasSesiones, sacarPendientes, resumen, fechaLocal};")();

let c = S.configuracion('{"url":"https://x.supabase.co/","anonKey":"k"}'); assert.deepEqual(c, { url: "https://x.supabase.co", anonKey: "k" });
assert.deepEqual(S.configuracion("basura{"), { url: S.URL_PROYECTO, anonKey: S.ANON_KEY });
// PKCE: el SHA-256 a mano coincide con el de Node, y el desafío S256 es su base64url.
for (const texto of ["", "abc", "a".repeat(55), "a".repeat(56), "a".repeat(64), "a".repeat(200)])
  assert.deepEqual(S.sha256([...Buffer.from(texto)]), [...crypto.createHash("sha256").update(texto).digest()], texto.length + " bytes");
const azar = "a1 b2 c3 d4 e5 f6 07 18 29 3a 4b 5c 6d 7e 8f 90\n 01 12 23 34 45 56 67 78 89 9a ab bc cd de ef f0\n";
const verificador = S.verificadorDesde(azar);
assert.equal(verificador, "a1b2c3d4e5f60718293a4b5c6d7e8f90" + "0112233445566778899aabbccddeeff0");
assert.equal(S.desafio(verificador), crypto.createHash("sha256").update(verificador).digest("base64url"));
assert.equal(S.verificadorDesde(""), ""); assert.equal(S.verificadorDesde("a1 b2"), ""); assert.equal(S.verificadorDesde("zz".repeat(32)), "");
assert.deepEqual(S.canjePkce("c", verificador), { auth_code: "c", code_verifier: verificador });

const pkce = "&code_challenge=" + S.desafio(verificador) + "&code_challenge_method=s256";
assert.equal(S.urlEntrar("https://x", "github", verificador), "https://x/auth/v1/authorize?provider=github&redirect_to=doro%3A%2F%2Fauth" + pkce);
assert.equal(S.urlVincular("", "google", verificador), "/auth/v1/user/identities/authorize?provider=google&redirect_to=doro%3A%2F%2Fauth&skip_http_redirect=true" + pkce);

// La vuelta trae un código para canjear; tokens sueltos en la URL ya no sirven.
assert.deepEqual(S.parsearRetorno("doro://auth?code=c%2D1"), { autorizacion: "c-1" });
assert.deepEqual(S.parsearRetorno("doro://auth/?code=c"), { autorizacion: "c" });
assert.equal(S.parsearRetorno("doro://auth#access_token=a&refresh_token=r&expires_in=3600").codigo, "falta_codigo");
assert.equal(S.parsearRetorno("doro://auth").codigo, "falta_codigo");
let r = S.parsearRetorno("doro://auth?error=server_error&error_code=identity_already_exists&error_description=Identity+is+already+linked");
assert.deepEqual(r, { error: "Identity is already linked", codigo: "identity_already_exists" });
r = S.parsearRetorno("doro://auth/#error=access_denied"); assert.equal(r.error, "access_denied");
assert.deepEqual(S.parsearRetorno("doro://auth#error=access_denied"), { error: "access_denied", codigo: "error" });
// Solo `doro://auth` exacto: ni otro esquema ni otro host que empiece igual.
for (const url of ["https://evil/?code=c", "doro://auth.evil.example/?code=c", "doro://authx?code=c", "doro://auth@evil/?code=c", "xdoro://auth?code=c", null])
  assert.equal(S.parsearRetorno(url).codigo, "retorno_invalido", String(url));

const ahora = 1_000_000_000_000;
const t = S.sesionDesdeRespuesta({ access_token: "a", refresh_token: "r", expires_in: 3600, user: { id: "u", is_anonymous: false, email: "e@x" } }, ahora);
assert.deepEqual(t, { access_token: "a", refresh_token: "r", expires_at: ahora + 3600_000, usuario: { id: "u", anonimo: false, nombre: "e@x" } });
assert.equal(S.sesionDesdeRespuesta({ access_token: "a", refresh_token: "r", expires_at: 2000000000 }, ahora).expires_at, 2_000_000_000_000);

const U = new Function(src + "; return usuarioDesde;")();
assert.equal(U({ id: "u", user_metadata: { full_name: "Ana" }, email: "a@x" }).nombre, "Ana");
assert.equal(U({ id: "u", user_metadata: {}, identities: [{ identity_data: { full_name: "Leo" } }], email: "l@x" }).nombre, "Leo");
assert.equal(U({ id: "u", is_anonymous: true }).nombre, ""); assert.equal(U({ id: "u", email: "e@x" }).nombre, "e@x");
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
