# /scripts — Changelog
Catat setiap perubahan file di folder `scripts/`. Newest di atas.

---

## `TradeOnlyFishIt.lua`

### Fix #5 — Refactor: HttpService + whitelist + GUI fallback + distance config
| | |
|---|---|
| **Tanggal** | 2026-01-07 |
| **Status** | PENDING commit |
| **File** | `scripts/TradeOnlyFishIt.lua` |
| **Masalah** | Versi awal pake `game:HttpGet` manual, auto-accept gak jalan, GUI fallback gak ada |
| **Akar** | `game:HttpGet` gak via HttpService; whitelist kosong; gak ada fallback ke klik GUI saat remote ditolak; jarak trade hardcoded 50 |
| **Perubahan** | |
| **1** | `loadstring(game:HttpGet("..."))` → tetap `game:HttpGet` di komentar, TAPI di kode pake `HttpService:GetHttpAsset` (lebih Roblox-native, bisa di-cache client) |
| **2** | Tambah `inWhitelist` table + `markWhitelisted(name)` — trade berhasil accept → masuk whitelist |
| **3** | Tambah `clickGuiButton(guiRoot, name)` — fallback klik Accept/Decline di PlayerGui kalau remote gak bisa di-fire |
| **4** | `KONFIG.TradeDistance = 40` (bisa di-tweak tanpa ubah logika) |
| **5** | `KONFIG.LoopInterval = 0.4` (interval loop auto-trade) |
| **6** | Remote hook `OnClientEvent` capture payload masuk (server→client) |
| **Verifikasi** | Belum di-test di Delta |

### Fix #4 — Script trade-only Fish It! pertama (Delta)
| | |
|---|---|
| **Tanggal** | 2026-01-07 |
| **Commit** | 17ae12b |
| **File** | `scripts/TradeOnlyFishIt.lua` |
| **Masalah** | Belum ada script trade-only di Fish It! |
| **Akar** | Baru dibuat |
| **Fitur** | Notif ON/OFF di layar, auto-detect trade remotes, late-bound observer, loop 0.5s |
| **Pelajaran** | Remote trade Fish It! bisa di-load lazy — wajib ada `DescendantAdded` observer |
