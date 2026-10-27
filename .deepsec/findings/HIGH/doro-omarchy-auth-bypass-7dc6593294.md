# [HIGH] OAuth implicit flow has no state/nonce: parsearRetorno accepts tokens from any doro://auth URL

**File:** [`Supabase.js`](https://github.com/daniace/doro-omarchy/blob/main/Supabase.js#L77-L126) (lines 77, 79, 84, 85, 114, 120, 122, 124, 126)
**Project:** doro-omarchy
**Severity:** HIGH  •  **Confidence:** high  •  **Slug:** `auth-bypass`

## Owners

**Suggested assignee:** `daniel.emiliano.acevedo@gmail.com` _(via last-committer)_

## Finding

urlEntrar() and urlVincular() build the Supabase /authorize URL with only `provider` and `redirect_to` — no `state`, nonce or PKCE verifier is generated, and nothing is stored to correlate a callback with a sign-in the user actually started. Correspondingly, parsearRetorno() performs exactly one check on the returning URL: `url.indexOf(REDIRECCION) !== 0` (L114). Anything whose first 11 characters are `doro://auth` is accepted, and the access_token/refresh_token are lifted straight out of the query string or fragment (L120-126).

Two defects compound:

1. **No origin binding.** There is no secret the client minted and can verify on return, so a callback forged by a third party is indistinguishable from a real one. `tests/supabase.test.mjs` L13-21 documents this exact acceptance behaviour.
2. **Loose prefix test.** `indexOf(...) !== 0` is a substring-prefix test, not a host test. `doro://auth.attacker.example/#access_token=A&refresh_token=R` passes: `resto` becomes `.attacker.example/#...`, the junk authority lands harmlessly in the query map, and the fragment tokens are returned as a valid session. Anyone eyeballing a browser's "open external app?" prompt would see an attacker hostname on what the code treats as a trusted Doro callback.

Delivery is not local-only. `Nube.qml` instalarManejador() (L294-300) registers `x-scheme-handler/doro` system-wide, pointing at `omarchy-shell doro.pomodoro authCallback %u`, and never deregisters it. After the user's first sign-in attempt, any web page can navigate to `doro://auth#access_token=<attacker>&refresh_token=<attacker>` and, behind a single browser confirmation, drive this parser with attacker-chosen tokens. See the companion finding in Nube.qml for the sink.

Note the error branch is evaluated before the token branch (L122-125), so an attacker also chooses which arm of recibirRetorno() runs by adding `error_code`.

## Recommendation

Adopt the PKCE/authorization-code flow (Supabase supports `flow_type: 'pkce'`), or at minimum: (1) generate a cryptographically random `state` per sign-in, append it to urlEntrar/urlVincular, persist it in memory with a short TTL, and have parsearRetorno require an exact match before returning tokens; (2) replace the prefix test with an exact authority check — parse the URL and require scheme `doro` and host/path exactly `auth`, rejecting `doro://authX` and `doro://auth.evil/`; (3) consume and clear the stored state so a captured callback cannot be replayed.

## Recent committers (`git log`)

- Daniel Emiliano Acevedo <daniel.emiliano.acevedo@gmail.com> (2026-10-27)
