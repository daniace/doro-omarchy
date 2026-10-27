// Pruebas de la lógica pura del reloj (Model.js). Correr con: node tests/model.test.mjs
// Model.js es un script de QML (`.pragma library`), así que se evalúa a mano en vez de importarlo.
import fs from "node:fs"; import assert from "node:assert/strict";
const src = fs.readFileSync(new URL("../Model.js", import.meta.url), "utf8").replace(".pragma library", "");
const M = new Function(src + "; return {duracionModo, modoAlTerminar, modoSiguiente, acotarMinutos, formatear, avance, suenaTick, estadoGuardado, CONFIGURACION_INICIAL};")();
const c = M.CONFIGURACION_INICIAL;
assert.equal(M.duracionModo("pomodoro", c), 1500); assert.equal(M.duracionModo("stopwatch", c), 0);
assert.equal(M.modoAlTerminar("pomodoro"), "shortBreak"); assert.equal(M.modoAlTerminar("longBreak"), "pomodoro");
assert.equal(M.modoSiguiente("shortBreak"), "longBreak"); assert.equal(M.modoSiguiente("longBreak"), "pomodoro");
assert.equal(M.acotarMinutos("shortBreak", 0), 1); assert.equal(M.acotarMinutos("pomodoro", 999), 180);
assert.equal(M.formatear(3600), "60:00"); assert.equal(M.formatear(-5), "00:00"); assert.equal(M.formatear(NaN), "00:00");
assert.equal(M.avance("stopwatch", 10, 0), null); assert.equal(M.avance("pomodoro", 750, 1500), 0.5);
assert.ok(M.suenaTick(11, 10)); assert.ok(M.suenaTick(6, 5)); assert.ok(M.suenaTick(12, 4)); assert.ok(!M.suenaTick(5, 4)); assert.ok(!M.suenaTick(20, 19));
let e = M.estadoGuardado("basura{"); assert.equal(e.modo, "pomodoro"); assert.equal(e.tiempoRestante, 1500);
e = M.estadoGuardado(JSON.stringify({configuracion:{pomodoro:50, autoBreak:true}, modo:"shortBreak", tiempoRestante:9e9, mezcla:{rain:40, x:3, fire:0}}));
assert.equal(e.configuracion.pomodoro, 50); assert.equal(e.configuracion.autoBreak, true); assert.equal(e.tiempoRestante, 300); assert.deepEqual(e.mezcla, {rain:40});
console.log("Model.js: todo OK");

// Salas
const S = new Function(src + "; return {parsearSala, esEstadoReloj, estadoParaSubir, aplicarRemoto, estadoGuardado, esUuid};")();
const uuid = "11111111-2222-3333-4444-555555555555";
assert.deepEqual(S.parsearSala("https://doro.page/invitacion/a1b2c3d4"), { codigo: "A1B2C3D4" });
assert.deepEqual(S.parsearSala(" a1b2 c3d4 "), { codigo: "A1B2C3D4" });
assert.deepEqual(S.parsearSala("https://doro.page/room/" + uuid.toUpperCase()), { salaId: uuid });
assert.deepEqual(S.parsearSala(uuid), { salaId: uuid });
assert.equal(S.parsearSala("ab"), null); assert.equal(S.parsearSala("hola mundo!"), null);
assert.ok(S.esEstadoReloj({ tiempoRestante: 300, estaActivo: false, modo: "shortBreak" }));
assert.ok(!S.esEstadoReloj({ timeLeft: 300, isActive: false, mode: "pomodoro" })); assert.ok(!S.esEstadoReloj(null));
assert.ok(!S.esEstadoReloj({ tiempoRestante: -1, estaActivo: false, modo: "pomodoro" }));

const t0 = Date.parse("2026-10-27T12:00:00.000Z"), conf = { pomodoro: 25, shortBreak: 5, longBreak: 15, autoBreak: false };
// Corriendo: tiempoRestante entero y `actualizadoEn` corrido al ancla exacta.
let sub = S.estadoParaSubir({ tiempoRestante: 0, estaActivo: true, modo: "pomodoro", configuracion: conf, tiempoFinObjetivo: t0 + 1499_300, tiempoInicioCronometro: 0 }, t0);
assert.equal(sub.tiempoRestante, 1500); assert.equal(Date.parse(sub.actualizadoEn) + 1500_000, t0 + 1499_300);
sub = S.estadoParaSubir({ tiempoRestante: 0, estaActivo: true, modo: "stopwatch", configuracion: conf, tiempoFinObjetivo: 0, tiempoInicioCronometro: t0 - 10_700 }, t0);
assert.equal(sub.tiempoRestante, 10); assert.equal(Date.parse(sub.actualizadoEn) - 10_000, t0 - 10_700);
sub = S.estadoParaSubir({ tiempoRestante: 42, estaActivo: false, modo: "pomodoro", configuracion: conf }, t0);
assert.equal(sub.tiempoRestante, 42); assert.equal(sub.actualizadoEn, "2026-10-27T12:00:00.000Z");
// Ida y vuelta: el otro reloj termina en el mismo instante.
let ap = S.aplicarRemoto(S.estadoParaSubir({ tiempoRestante: 0, estaActivo: true, modo: "pomodoro", configuracion: conf, tiempoFinObjetivo: t0 + 1499_300 }, t0), conf, t0 + 2000);
assert.equal(ap.tiempoFinObjetivo, t0 + 1499_300); assert.equal(ap.estaActivo, true); assert.equal(ap.vencido, false);
// Config de la sala, acotada; en pausa se aplica tal cual.
ap = S.aplicarRemoto({ tiempoRestante: 300, estaActivo: false, modo: "shortBreak", configuracion: { pomodoro: 999, shortBreak: 5, longBreak: 15, autoBreak: true } }, conf, t0);
assert.equal(ap.configuracion.pomodoro, 180); assert.equal(ap.configuracion.autoBreak, true); assert.equal(ap.tiempoInicial, 300); assert.equal(ap.estaActivo, false);
// Sin `configuracion` (filas viejas) se queda con la local.
assert.equal(S.aplicarRemoto({ tiempoRestante: 60, estaActivo: false, modo: "pomodoro" }, conf, t0).tiempoInicial, 1500);
// Terminada hace un rato: vencida; recién terminada: la cierra este reloj.
assert.equal(S.aplicarRemoto({ tiempoRestante: 60, estaActivo: true, modo: "pomodoro", actualizadoEn: new Date(t0 - 3600_000).toISOString() }, conf, t0).vencido, true);
ap = S.aplicarRemoto({ tiempoRestante: 60, estaActivo: true, modo: "pomodoro", actualizadoEn: new Date(t0 - 61_000).toISOString() }, conf, t0);
assert.equal(ap.vencido, false); assert.equal(ap.tiempoRestante, 0);
ap = S.aplicarRemoto({ tiempoRestante: 10, estaActivo: true, modo: "stopwatch", actualizadoEn: new Date(t0 - 5000).toISOString() }, conf, t0);
assert.equal(ap.tiempoRestante, 15); assert.equal(ap.tiempoInicioCronometro, t0 - 15_000);
// La sala guardada.
assert.deepEqual(S.estadoGuardado(JSON.stringify({ sala: { id: uuid, codigo: "AB12" } })).sala, { id: uuid, codigo: "AB12" });
assert.equal(S.estadoGuardado(JSON.stringify({ sala: { id: "x" } })).sala, null);
console.log("Model.js (salas): todo OK");
