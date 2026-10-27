# [MEDIUM] Token file mode is inherited, not set; the only guaranteed protection is an unverified async chmod

**File:** [`Nube.qml`](https://github.com/daniace/doro-omarchy/blob/main/Nube.qml#L140-L336) (lines 140, 143, 281, 283, 335, 336)
**Project:** doro-omarchy
**Severity:** MEDIUM  •  **Confidence:** low  •  **Slug:** `other-insecure-file-permissions`

## Owners

**Suggested assignee:** `daniel.emiliano.acevedo@gmail.com` _(via last-committer)_

## Finding

`establecerSesion` writes bearer tokens with `archivoSesion.setText(...)` (L143) and the plugin never sets an explicit mode on the file. The sole protection is `Process { command: ["chmod", "700", root.carpetaEstado] }` (L281-284), which is (a) started asynchronously from `cargar()` and races the FileView writes that `crearCarpeta.onExited` kicks off in parallel, and (b) has no `onExited` handler, so a failure (missing `chmod`, or a state dir on a filesystem that cannot represent the mode, e.g. a FAT/exFAT/NFS `XDG_STATE_HOME`) is silent and leaves the directory at `mkdir -p`'s umask default of 0755.

I verified the live directory is 0700 and `sesion.json` happens to be 0600 — but that mode is incidental, not enforced: its three siblings written through the identical `atomicWrites` FileView path (`omarchy.json`, `pendientes.json`, `icono-aviso.svg`) are all 0644 under the same 0022 umask. So the atomic-write path demonstrably does produce world-readable files, and if `sesion.json` is ever (re)created along that branch — or restored from a backup at 0644 — the credential file is world-readable with only the directory mode standing between it and other local accounts. Reported at low confidence because the observed state is currently safe.

## Recommendation

Make the hardening explicit and ordered rather than racing: create the directory with `mkdir -m 700 -p`, gate the first FileView write on that process exiting successfully, and log loudly if it fails. Additionally chmod 600 `sesion.json` after each write (or write it via a path that sets the mode explicitly) so the credential file does not depend on umask or on a pre-existing file's mode.

## Recent committers (`git log`)

- Daniel Emiliano Acevedo <daniel.emiliano.acevedo@gmail.com> (2026-10-27)
