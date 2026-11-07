# /scripts — Changelog
Catat setiap perubahan file di folder `scripts/`. Newest di atas.

---

## `TradeOnlyFishIt.lua`

### Fix #7 — Bug runtime: `Dimension.new`, `+=`, `continue` (ini penyebab "ga on")
| | |
|---|---|
| **Tanggal** | 2026-11-07 |
| **File** | `scripts/TradeOnlyFishIt.lua` |
| **Masalah** | Script di-inject tapi tidak ada notifikasi ON/OFF sama sekali; di-eval tanpa error yang kelihatan |
| **Akar** | Tiga bug nyata di kode versi Fix #6: |
| **1** | Baris 89 `label.Padding = Dimension.new(12, 2)` — `Dimension` **bukan class Roblox**, dan `TextLabel` tak punya properti `Padding`. Crash tepat di dalam `notify()`, jadi notifikasi pertama (yang seharusnya jadi bukti script jalan) malah membunuh script |
| **2** | Baris 101 `t += 0.02` — operator `+=` hanya Luau/compound assignment. Di path fade animasi |
| **3** | Empat `continue` di `autoTradeLoop()` (`continue` = ekstensi Luau, bukan Lua 5.4) |
| **Perubahan** | |
| **1** | `Dimension.new` → `Instance.new("UIPadding")` + `UDim.new` untuk Left/Right/Top/Bottom, di-parent ke label |
| **2** | `t += 0.02` → `t = t + 0.02` (dan `count += 1` → `count = count + 1`, sama-sama gak konsisten) |
| **3** | `autoTradeLoop()` ditulis ulang tanpa `continue`: `if tradeModeActive then ... end` + `if/elseif` bersarang. Perilaku sama, tapi tak mungkin ada variabel yang undefined |
| **4** | Tambah harness `/tmp/opencode/roblox_harness.lua` — stub `Instance`/`Enum`/`UDim2`/`Color3`/`task` yang melaporkan properti ilegal sebagai error |
| **Verifikasi** | `luac5.4 -p TradeOnlyFishIt.lua` → **SYNTAX OK**. Harness: **Total masalah: 0**, log `3 trade remotes found` + `Trade-only mode: ON` (setelah toggle key T diuji lewat `InputBegan`) |
| **Pelajaran** | `luac -p` cuma nangkap sintaks Lua; `Dimension.new` lolos karena valid secara sintaks. Yang nangkap typo Instance adalah harness stub. Selalu jalanin keduanya sebelum minta user test |
| **Deploy** | Autoexecute + Salinan di `/sdcard/Delta/Scripts/RobloxDebug/` disinkronkan ke md5 `f0fd208a5a3314428bd21827dee1abb0` |

### Fix #6 — Ganti loadstring ke HttpService:GetHttpAsset + update Delta Autoexecute
| | |
|---|---|
| **Tanggal** | 2026-01-07 |
| **Status** | PENDING commit |
| **File** | `scripts/TradeOnlyFishIt.lua` |
| **Masalah** | File Delta masih `game:HttpGet`; Autoexecute masih versi lama (md5 beda); file `Enter Your Title...` tanpa ekstensi `.lua` gak ke-execute Delta |
| **Akar** | `game:HttpGet` bukan HttpService; Autoexecute gak di-sync ke versi Fix #5; nama file Delta tanpa `.lua` bikin Delta skip |
| **Perubahan** | |
| **1** | Header loadstring → `HttpService:GetHttpAsset` (Roblox-native, bisa cache) |
| **2** | Hapus referensi `HttpService` di body script (gak dipake, cuma di header) |
| **3** | Update `/sdcard/Delta/Scripts/RobloxDebug/TradeOnlyFishIt.lua` (salinan lengkap versi baru) |
| **4** | Sync `/sdcard/Delta/Autoexecute/TradeOnlyFishIt.lua` ke md5 `2f87d5c7` (versi Fix #5) |
| **Verifikasi** | md5 local = md5 live GitHub = md5 Autoexecute (semua `2f87d5c7`) |

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
