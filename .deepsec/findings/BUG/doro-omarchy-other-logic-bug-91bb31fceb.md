# [BUG] Remote timer state has no upper bound in the timer branch, overflowing the int clock

**File:** [`Service.qml`](https://github.com/daniace/doro-omarchy/blob/main/Service.qml#L263-L272) (lines 263, 269, 271, 272)
**Project:** doro-omarchy
**Severity:** BUG  •  **Confidence:** high  •  **Slug:** `other-logic-bug`

## Owners

**Suggested assignee:** `daniel.emiliano.acevedo@gmail.com` _(via last-committer)_

## Finding

`aplicarRemoto` assigns `estado.tiempoRestante` straight into `property int tiempoRestante` (L271). `Model.esEstadoReloj` bounds the *remote* `tiempoRestante` to `MAX_SEGUNDOS_VALIDOS`, but `actualizadoEn` is never validated, and `Model.aplicarRemoto` derives the local value from it: the stopwatch branch clamps with `Math.min(MAX_SEGUNDOS_VALIDOS, ...)` (Model.js:197) while the timer branch does not (Model.js:199-200) — a clear asymmetry showing the missing clamp is unintentional.

A room member (or a corrupted `rooms.timer_state` row) posting `{tiempoRestante: 0, estaActivo: true, modo: "pomodoro", actualizadoEn: "9999-01-01T00:00:00Z"}` passes every validator. `referencia` becomes ~2.5e14 ms, so `tiempoFinObjetivo` is ~8000 years out and `tiempoRestante` is ~2.5e11 seconds — far past INT32_MAX, so the QML int property truncates/wraps (possibly negative). `vencido` stays false, `estaActivo` stays true, and `actualizar()` (L167-182) recomputes the same out-of-range value every 200 ms, so the phase can never end and the bar shows a frozen/garbage time. The persisted value is sanitized by `Model.estadoGuardado` on reload, so a shell restart recovers; until then the clock needs a manual reset. Classified as a bug rather than a vulnerability because any room member already controls the shared timer by design — the defect is the unbounded value escaping the documented `MAX_SEGUNDOS_VALIDOS` contract.

## Recommendation

Clamp the timer branch the same way as the stopwatch branch in `Model.aplicarRemoto`: `estado.tiempoRestante = Math.min(MAX_SEGUNDOS_VALIDOS, Math.max(0, Math.ceil((estado.tiempoFinObjetivo - ahora) / 1000)))`, and reject states whose `Date.parse(actualizadoEn)` is more than a small margin in the future (treat them as `vencido` or ignore them) inside `Model.esEstadoReloj`.

## Recent committers (`git log`)

- Daniel Emiliano Acevedo <daniel.emiliano.acevedo@gmail.com> (2026-10-27)
