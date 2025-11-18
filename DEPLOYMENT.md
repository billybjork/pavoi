# Hudson Desktop Deployment (Tauri + Phoenix)

Ship Hudson as a cross‑platform desktop app using **Tauri** as the shell, while keeping the existing **Phoenix/LiveView** UI and adding a **SQLite + Neon** hybrid data layer plus media caching.

## 🎯 Quick Start (Pilot)

**The pilot is complete and working!** To test the native desktop app:

```bash
./run_native.sh
```

This launches a native macOS window with the full Hudson LiveView UI, backed by a 25MB single-binary BEAM release with SQLite local cache.

### Database Modes

The app supports three database modes via `HUDSON_ENABLE_NEON`:

```bash
# Local Postgres (default for development)
./run_native.sh                              # or double-click Hudson.app

# Neon cloud database (production)
HUDSON_ENABLE_NEON=true DATABASE_URL=... ./run_native.sh

# Offline mode (SQLite only)
HUDSON_ENABLE_NEON=false ./run_native.sh
```

## 🔧 Troubleshooting

### App Hangs on "Starting Hudson..." (Dock Launch)

**Symptom**: App works when launched from terminal but hangs when launched from Finder/dock.

**Cause**: Missing network entitlements or missing platform-specific binary symlink.

**Fix**:
1. Ensure `src-tauri/entitlements.plist` exists with network permissions
2. Create symlink in app bundle:
   ```bash
   cd src-tauri/target/release/bundle/macos/Hudson.app/Contents/MacOS
   ln -sf hudson_macos_arm hudson_macos_arm-aarch64-apple-darwin
   ```
3. Remove dock bookmark and re-add it

### Backend Code Changes Not Reflected

**Symptom**: Rebuilt the burrito binary but app still uses old code.

**Cause**: Burrito caches the extracted runtime in `~/Library/Application Support/.burrito/`.

**Fix**:
```bash
# Clear burrito cache
rm -rf ~/Library/Application\ Support/.burrito/hudson_erts-*

# Rebuild
MIX_ENV=prod mix release --overwrite
cargo tauri build

# Create symlink (if needed for dock)
cd src-tauri/target/release/bundle/macos/Hudson.app/Contents/MacOS
ln -sf hudson_macos_arm hudson_macos_arm-aarch64-apple-darwin
```

### Pages Show "Internal Server Error"

**Symptom**: App starts but pages like `/products` crash.

**Cause**: Page tries to query `Hudson.Repo` (Postgres) which isn't running in offline mode.

**Fix**: Either:
- Use `HUDSON_ENABLE_NEON=local` to connect to local Postgres (recommended for development)
- Or update the page to gracefully handle offline mode (check if Repo is started)

## 📌 Latest Progress

### 2025-11-18
- ✅ **Windows cross-compilation blocker resolved**: Removed unused NIF dependencies (bcrypt_elixir, lazy_html) that were causing build issues
  - bcrypt_elixir was vestigial - Hudson has no authentication system
  - lazy_html was inherited from Phoenix LiveView but never used in production code
  - Only remaining NIF is exqlite (SQLite driver), which Burrito handles cleanly
  - Cross-platform Windows builds should now be possible (pending testing)
- ✅ **Dependency cleanup**: Reduced total dependencies from 92 to 88 packages
- ✅ **Updated runtime smoke checks**: Now validates only exqlite NIF loading

### 2025-11-17
- ✅ **Database mode configuration complete**: Added three-mode `HUDSON_ENABLE_NEON` support:
  - `true` - Neon cloud database (production)
  - `local` - Local PostgreSQL (development, now the default)
  - `false` - Offline mode (SQLite only)
- ✅ **macOS entitlements added**: Created `src-tauri/entitlements.plist` with network permissions to fix `:eperm` errors when launching app via dock
- ✅ **Burrito cache location documented**: `~/Library/Application Support/.burrito/hudson_erts-*/` - must be cleared when updating backend code
- ✅ **App bundle symlink fix**: Added `hudson_macos_arm-aarch64-apple-darwin` symlink in app bundle for dock launches
- ✅ **Default mode changed to local**: Both Tauri app and `run_native.sh` now default to local Postgres for easier development
- ✅ Added a minimal **local sync operations queue** on SQLite with helpers + tests. Supports enqueue/pending/done/failed. Sync worker/backoff to Neon is still pending.
- ✅ Burrito targets are now configurable via `HUDSON_BURRITO_TARGETS`. Default: macOS ARM. `all` adds macOS Intel + Windows targets (see `mix.exs` release config).
- ✅ **Tauri automated bundling now working!** Bundle created at `src-tauri/target/release/bundle/macos/Hudson.app` and verified working with `./run_native.sh`.

## ⚠️ Current State

### ✅ Completed (Pilot - macOS ARM only)
- ✅ Phoenix LiveView app running in desktop mode with three database modes (Neon/local/offline)
- ✅ Shopify & OpenAI API integrations
- ✅ esbuild asset pipeline (no npm)
- ✅ Oban background jobs
- ✅ **Tauri desktop shell** - spawns BEAM, reads handshake, loads WebView, handles lifecycle
- ✅ **Burrito single-binary packaging (macOS ARM)** - 25MB binary with all NIFs validated
- ✅ **Health check endpoint** (`/healthz`)
- ✅ **Port handshake mechanism** (`/tmp/hudson_port.json`)
- ✅ **SQLite local cache structure** (schema + auto-migrations on startup)
- ✅ **Secure storage pattern** (file-based for pilot, OS keychain ready for production)
- ✅ **macOS entitlements** for network access (dock launches working)
- ✅ **Three-mode database config** (`HUDSON_ENABLE_NEON`: true/local/false)

### 🔄 Next: Production-Ready Desktop
- ❌ Multi-platform support (Windows, macOS Intel) - pilot is macOS ARM only
- ❌ Sync worker/backoff to push local SQLite queue to Neon (queue + schema exist, worker pending)
- ❌ Full OS keychain/DPAPI integration (currently file-based)
- ❌ First-run wizard UI (bootstrap code exists, needs UI)
- ❌ Media cache system (not implemented)
- ❌ Auto-update mechanism (not implemented)
- ❌ CI/CD pipeline with code signing (not configured)

## Architecture Overview

**High-Level Components:**
- **Tauri shell** (Rust): boots BEAM release, manages lifecycle, loads Phoenix UI in WebView on `http://127.0.0.1:<ephemeral_port>`. No UI rewrite needed.
- **Phoenix/LiveView** (unchanged UI): served locally on loopback with random port.
- **Data**: SQLite for low-latency/offline cache + Neon Postgres as source of truth. Operation queue syncs to Neon with retries.
- **Media**: disk cache (planned) with TTL/size cap for product images.
- **Updates**: Tauri updater (planned) with signature verification and rollback.
- **Secrets**: File-based for pilot; OS keychain (macOS) / DPAPI (Windows) for production.

**Key Design Principles:**
- Preserve LiveView UI - no template rewrites
- Local-first for offline tolerance, Neon as authoritative source
- No client-run migrations against Neon (CI/CD only)
- Bind Phoenix to loopback only on ephemeral port
- Single-binary distribution via Burrito + Tauri installers

## Next Steps for Production

### Priority 1: Core Functionality

**1. Sync Worker**
- GenServer with exponential backoff to sync SQLite queue → Neon
- Circuit breaker for extended offline periods
- Conflict resolution (last-write-wins for products, user choice for sessions)

**2. First-Run Wizard UI**
- Multi-step LiveView at `/setup/welcome`
- Collect: Neon URL, Shopify creds, OpenAI key
- Test connections, initial sync, then redirect to app

**3. OS Keychain Integration**
- macOS: Keychain Access via Rust bridge
- Windows: DPAPI/WinCred via Rust bridge
- Unified `Hudson.SecureStorage` API (get/put/delete)

### Priority 2: Multi-Platform

**4. Cross-Platform Builds**
- Test macOS Intel and Windows builds (NIF blocker now resolved)
- Validate Zig cross-compilation workflow
- Update `HUDSON_BURRITO_TARGETS` for all platforms

**5. CI/CD Pipeline**
- GitHub Actions: matrix builds for macOS (ARM + Intel) + Windows
- Code signing: macOS notarization + Windows Authenticode
- Automated smoke tests (NIF loading, health check, window launch)

### Priority 3: Production Polish

**6. Media Cache**
- Req-based disk cache with LRU/TTL logic
- Prefetch product images when online
- Serve from cache or placeholders when offline

**7. Auto-Updater**
- Tauri updater with signature verification
- Atomic binary swap with rollback capability
- Staged rollout by channel (stable/beta)

**8. Diagnostics UI**
- LiveView page: Neon connectivity, API status, sync queue depth, cache stats
- Offline/online indicator in navbar
- Manual "Sync Now" button

## Offline/Online Capability Matrix

| Feature                  | Offline | Online Required |
|--------------------------|---------|-----------------|
| View cached products     | ✅       | —               |
| View fresh products      | ❌       | ✅              |
| Create session (local)   | ✅       | —               |
| Add products to session  | ✅       | —               |
| Generate talking points  | ❌       | ✅ (OpenAI)     |
| Shopify sync             | ❌       | ✅              |
| Start live stream        | ✅       | ✅ (TikTok APIs)|

## Security & Production Readiness

**Current (Pilot):**
- File-based secret storage in `~/Library/Application Support/Hudson/`
- Secrets generated on first run, persisted to disk
- TLS for all external API calls (Neon, Shopify, OpenAI)

**Production Requirements:**
- OS keychain (macOS) / DPAPI (Windows) for credential storage
- Code signing + notarization for all installers
- Log redaction for DATABASE_URL and API keys
- Update signature verification (GPG or equivalent)
- Schema version gating (refuse to start if Neon schema too new)

## Notes & Risks

**Current Code Risks:**
- Production will need first-run wizard - bootstrap code exists but no UI yet
- Sync worker pending - local queue exists but no background process to push to Neon
- Windows/Intel builds untested (NIF dependencies now clean, should work)

**Known Limitations:**
- Pilot is macOS ARM only
- No automatic updates yet (manual app replacement required)
- No diagnostics/health dashboard yet
- File-based secrets (not OS keychain)

## Resources

- **Tauri Documentation:** https://tauri.app/v1/guides/
- **Burrito + Tauri Guide:** https://mrpopov.com/posts/elixir-liveview-single-binary/
- **Ecto SQLite:** https://hexdocs.pm/ecto_sqlite3
- **Phoenix Releases:** https://hexdocs.pm/phoenix/releases.html
