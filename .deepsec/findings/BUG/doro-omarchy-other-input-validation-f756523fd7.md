# [BUG] aplicarRemoto drops the MAX_SEGUNDOS_VALIDOS bound in the countdown branch, letting a room peer overflow the timer

**File:** [`Model.js`](https://github.com/daniace/doro-omarchy/blob/main/Model.js#L133-L200) (lines 133, 136, 179, 197, 199, 200)
**Project:** doro-omarchy
**Severity:** BUG  •  **Confidence:** medium  •  **Slug:** `other-input-validation`

## Owners

**Suggested assignee:** `daniel.emiliano.acevedo@gmail.com` _(via last-committer)_

## Finding

esEstadoReloj() carefully bounds `tiempoRestante` to [0, MAX_SEGUNDOS_VALIDOS] (L136), but aplicarRemoto() then *derives* a new tiempoRestante from a second, completely unvalidated peer-controlled field — `remoto.actualizadoEn` — and the two branches treat it inconsistently:

- stopwatch branch (L196-197): clamps with `Math.min(MAX_SEGUNDOS_VALIDOS, Math.max(0, ...))`. Safe.
- countdown branch (L199-200): `tiempoFinObjetivo = referencia + remoto.tiempoRestante * 1000` then `tiempoRestante = Math.max(0, Math.ceil((tiempoFinObjetivo - ahora) / 1000))`. No upper bound at all.

`referencia` is `Date.parse(remoto.actualizadoEn)` and esEstadoReloj never checks that field's type or range, so any room member can publish `{modo:"pomodoro", estaActivo:true, tiempoRestante:1, actualizadoEn:"+275760-09-13T00:00:00.000Z"}` and produce a derived tiempoRestante around 8.6e12 — six orders of magnitude past the documented invariant.

That value is then assigned to `property int tiempoRestante` in Service.qml L29. QML int coercion applies ToInt32, so it wraps modulo 2^32 and can land negative. Downstream, Model.formatear() clamps the display and Model.avance() clamps the ring, so there is no crash — but the shared timer is stuck: the 200 ms tick recomputes the same out-of-range value from tiempoFinObjetivo every cycle, so the phase never ends, terminarFase() never runs, and the only recovery is leaving the room. This is precisely the "MAX_SEGUNDOS_VALIDOS bound being dropped" case the project flags, reached through the anchor field rather than the bounded one.

## Recommendation

Validate `actualizadoEn` in esEstadoReloj (require a string that Date.parse resolves to a finite timestamp within a sane window of now, e.g. +/- 24h), and apply the same `Math.min(MAX_SEGUNDOS_VALIDOS, ...)` clamp to the countdown branch's derived tiempoRestante that the stopwatch branch already uses. Clamp tiempoFinObjetivo to `ahora + MAX_SEGUNDOS_VALIDOS * 1000` so a bogus anchor cannot park the phase indefinitely.

## Recent committers (`git log`)

- Daniel Emiliano Acevedo <daniel.emiliano.acevedo@gmail.com> (2026-10-27)
