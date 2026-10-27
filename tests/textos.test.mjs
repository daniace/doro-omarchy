// Pruebas de los textos visibles (Textos.js). Correr con: node tests/textos.test.mjs
// Textos.js es un script de QML (`.pragma library`), así que se evalúa a mano en vez de importarlo.
import fs from "node:fs"; import assert from "node:assert/strict";
const src = fs.readFileSync(new URL("../Textos.js", import.meta.url), "utf8").replace(".pragma library", "");
const T = new Function(src + "; return {TEXTOS, idiomaElegido, t, resumen, aviso};")();

// Los dos idiomas tienen las mismas claves y los mismos {valores}.
const claves = (idioma) => Object.keys(T.TEXTOS[idioma]).sort();
assert.deepEqual(claves("es"), claves("en"));
const valores = (texto) => (texto.match(/\{[a-z]+\}/gi) || []).sort().join();
for (const clave of claves("en")) if (clave !== "cuenta.resumen") assert.equal(valores(T.TEXTOS.es[clave]), valores(T.TEXTOS.en[clave]), clave);

// Cada uso de t("…") en los QML existe en la tabla.
for (const archivo of ["Panel.qml", "Service.qml", "Nube.qml", "Sala.qml", "BarWidget.qml"]) {
  const qml = fs.readFileSync(new URL("../" + archivo, import.meta.url), "utf8");
  for (const [, clave] of qml.matchAll(/\bt\("([a-zA-Z.]+)"\s*[,)]/g)) assert.ok(clave in T.TEXTOS.en, archivo + ": " + clave);
}

assert.equal(T.idiomaElegido("es", "en_US.UTF-8"), "es"); assert.equal(T.idiomaElegido("", "es_AR.UTF-8"), "es");
assert.equal(T.idiomaElegido("", "en_US.UTF-8"), "en"); assert.equal(T.idiomaElegido("fr", ""), "en"); assert.equal(T.idiomaElegido("", "est_EE"), "en");
assert.equal(T.t("es", "sala.nombre", { codigo: "AB12" }), "Sala AB12"); assert.equal(T.t("en", "sala.nombre", { codigo: "AB12" }), "Room AB12");
assert.equal(T.t("xx", "modo.shortBreak"), "Short break"); assert.equal(T.t("es", "no.existe"), "no.existe");
assert.equal(T.resumen("es", 50, 1), "Hoy 50 min · racha de 1 día"); assert.equal(T.resumen("es", 0, 3), "Hoy 0 min · racha de 3 días");
assert.equal(T.resumen("en", 25, 2), "Today 25 min · 2-day streak");
assert.deepEqual(T.aviso("en", "shortBreak"), { titulo: "Break finished", cuerpo: "Back to focus." });
console.log("Textos.js: todo OK");
