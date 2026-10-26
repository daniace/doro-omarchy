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
