# Multi-Tenancy Feasibility Audit for Pavoi

*Audit Date: January 2026*
*Updated: February 6, 2026 — implementation complete, ready for operational validation*

## Executive Summary

**Current State:** The Pavoi codebase is now **~95% multi-tenant ready**. All core implementation phases are complete: brand-scoped database schema, magic-link authentication, invite-only access, brand routing (path + custom domain), brand switcher UX, query scoping across all contexts, per-brand background jobs, and external integration support via Settings module with env var fallbacks.

**Remaining work:** Operational validation — onboarding a second brand end-to-end, custom domain DNS/SSL setup, and verifying data isolation across all flows.

**Key design decisions (updated):**
- **Authentication:** Magic link (passwordless) login using Phoenix 1.8's built-in `mix phx.gen.auth` generator — no custom auth code needed
- **Multi-brand access:** Users can belong to multiple brands (e.g., "Pavoi Active" and "Pavoi Jewelry") and switch between them via a top-level brand switcher in the nav bar
- **Routing:** Dual-mode — path-based (`/b/:brand_slug/...`) on the default host, and host-based for custom domains

---

## Status Update (Feb 6, 2026)

### Implementation Complete ✓

**Database & Schema:**
- Brand-scoped migrations for all tables (streams, comments, stats, auth, creator activity, templates, presets, settings)
- Brand-scoped unique indexes for products, product sets, and live stream capturing
- 16 new migrations landed

**Authentication & Authorization:**
- Magic-link auth via `phx.gen.auth` (passwordless, no legacy password auth)
- Invite-only access (no public registration)
- Legacy auth files removed (`require_password.ex`, `auth_controller.ex`, `auth_html/*`)
- `user_brands` join table + role-based brand access
- Admin users with cross-brand access

**Routing & Brand Resolution:**
- Dual-mode routing: path-based (`/b/:brand_slug/...`) + custom domain (host-based)
- `BrandAuth` on_mount hooks for brand resolution and access control
- `BrandRoutes` helpers for brand-aware URL generation
- Brand switcher dropdown in nav bar

**Query Scoping & Jobs:**
- All context modules scoped by `brand_id` (Catalog, ProductSets, Creators, TiktokLive, TiktokShop, Settings, Communications)
- PubSub topics namespaced by brand
- All Oban workers accept `brand_id` in job args
- Default-brand fallbacks removed from workers

**External Integrations:**
- Per-brand TikTok Shop OAuth + token storage
- Settings module provides per-brand config with env var fallbacks for: SendGrid, BigQuery, Slack, Shopify
- Brand-aware email sender (from name/address per brand)

### Operational Validation Remaining
- Onboard a second brand end-to-end using the checklist (§12)
- Configure custom domain DNS + SSL for a brand
- Verify data isolation across all core flows (product sync, streams, outreach, orders)

---

## Requirements (Confirmed)

| Decision | Choice |
|----------|--------|
| **TikTok App Strategy** | Shared App - brands OAuth into your existing TikTok app |
| **Feature Scope** | All features ideally; Product Sets + Products + Streams priority |
| **Onboarding Model** | Self-service (aim for it) |
| **Data Isolation** | Brand-scoped data, but **creators can be shared across brands** |
| **User Registration** | Invite-only (no public signup) |
| **Custom Domains** | Yes — brands can have their own domain; default host used otherwise |

### Implications of Shared Creators
Creators can be shared across brands, which changes the data model:
- Keep the `brand_creators` junction table to relate creators ↔ brands
- Creator identity fields remain global (`tiktok_user_id`, email, profile, etc.)
- **Brand-specific activity** must be scoped by brand:
  - `creator_videos`, `creator_performance_snapshots`, `creator_purchases`, `outreach_logs`, and any outreach/consent tracking
- Authorization must check **brand access via `brand_creators`** (and user-brand access separately)

This avoids duplicating creator records while still isolating operational data per brand.

---

## 1. Database Schema Assessment

### Already Multi-Tenant Ready (9 tables)
| Table | Isolation Method |
|-------|-----------------|
| `brands` | Root tenant table |
| `products` | Direct `brand_id` FK |
| `product_images` | Via `products.brand_id` |
| `product_variants` | Via `products.brand_id` |
| `product_sets` | Direct `brand_id` FK |
| `product_set_products` | Via `product_sets.brand_id` |
| `product_set_states` | Via `product_sets.brand_id` |
| `brand_creators` | Junction table (brand ↔ creator) |
| `creator_tags` | Direct `brand_id` FK |

### Brand Isolation Completed (Feb 2026)
| Table | Update |
|-------|--------|
| `tiktok_streams` | `brand_id` added + backfilled (from product sets / default brand) |
| `tiktok_comments` | `brand_id` added + backfilled from streams |
| `tiktok_stream_stats` | `brand_id` added + backfilled from streams |
| `tiktok_shop_auth` | `brand_id` added, singleton removed, unique per-brand auth enforced |
| `outreach_logs` | `brand_id` added + indexed |
| `email_templates` | `brand_id` added + unique per-brand names |
| `system_settings` | `brand_id` added + unique per-brand keys (used as brand settings) |
| `message_presets` | `brand_id` added (now brand-scoped) |

### Creators Brand Isolation (Completed)
Creators remain global (no `brand_id` on `creators`), while brand-specific activity now carries `brand_id`:
- `creator_videos`
- `creator_performance_snapshots`
- `creator_purchases`
- `outreach_logs`

The `brand_creators` junction table remains the access control layer for creator↔brand relationships.

### Unique Index Changes (Completed)
- `products.pid` → unique on `{brand_id, pid}` (partial)
- `products.tiktok_product_id` → unique on `{brand_id, tiktok_product_id}` (partial)
- `product_sets.slug` → unique on `{brand_id, slug}`
- `tiktok_streams` capturing index → unique on `{brand_id, room_id}` where `status = 'capturing'`

---

## 2. External API Integrations

### TikTok Shop API (CRITICAL)
**Current (Implemented):**
- Per-brand OAuth tokens stored in `tiktok_shop_auth` with `brand_id`
- Redundant unique index on `id` removed; unique index now on `brand_id`
- OAuth callback uses a signed `state` token to bind callback → brand
- `TiktokShop` context accepts `brand_id` for API calls

**Still Required:**
- Remove remaining default-brand fallbacks (e.g., `get_auth/1` with hardcoded `"pavoi"`)
- Schedule token refresh + sync per brand (not via default slug)
- Add UI/brand settings flow to initiate OAuth (`generate_authorization_url/1`)

**Implementation (already in codebase):**
```elixir
# Migration: Add brand_id to tiktok_shop_auth
alter table(:tiktok_shop_auth) do
  add :brand_id, references(:brands, on_delete: :delete_all), null: false
end
drop unique_index(:tiktok_shop_auth, [:id])  # Remove redundant unique index
create unique_index(:tiktok_shop_auth, [:brand_id])  # One auth per brand

# Update TiktokShop module to accept brand_id
def get_auth(brand_id) do
  Repo.get_by(Auth, brand_id: brand_id)
end
```

**OAuth Flow for Brand Onboarding (Critical: bind callback to brand via `state`):**
1. Brand clicks "Connect TikTok Shop" in settings
2. Generate a signed `state` token (Phoenix.Token) that encodes `brand_id` + nonce
3. Redirect to TikTok OAuth: `services.us.tiktokshop.com/open/authorize?service_id=...&state=<token>` (US) or `services.tiktokshop.com/open/authorize?...` (Global)
4. TikTok redirects back to `/tiktok/callback` with `auth_code` + `state`
5. Verify `state`, extract `brand_id`, exchange code for tokens, store with `brand_id`

> **Note:** The TikTok Shop Owner account (not just an admin/sub-account) must perform the authorization. Only the main account holder has authority to authorize third-party apps. The shop region (US vs Global) determines which authorization URL to use.

### BigQuery
**Current:** Single project/dataset via environment variables
**Fix:** Store credentials per-brand in database table, or use single project with brand-namespaced tables

### Shopify
**Current:** Single store credentials in env vars
**Fix:** Each brand links their own Shopify store via OAuth flow

**Additional change required:**
- Remove vendor-based auto brand creation in `ShopifySyncWorker` (currently derives brand from `product.vendor`)
- Use the **current brand’s store credentials** to scope all Shopify syncs and product creation

### Slack, SendGrid, OpenAI
**Current:** Global API keys
**Fix:** Either share (with brand metadata in payloads) or store per-brand credentials

### Custom Domains (Cross-cutting)
**Required:** Brand settings must store the primary domain/base URL.
- Brand-aware URLs are now generated via `BrandRoutes.brand_url/2` (verify coverage).
- `config/runtime.exs` uses `check_origin: :conn`; verify this works for all brand domains.

---

## 3. Authentication & Authorization

### Current State (Updated)
- **Magic link auth is implemented** via `phx.gen.auth` and router uses the new auth pipelines
- `user_brands` table + Accounts helpers exist, and brand access is enforced via `BrandAuth`
- Legacy `SITE_PASSWORD` auth files still exist but are unused
- Login UI still shows password login + signup link; invite-only UX is not wired yet

### Strategy: Magic Link Auth via Phoenix 1.8 Generator

Phoenix 1.8 (already in use — the project is on 1.8.1) ships with `mix phx.gen.auth` that generates **magic link authentication by default**. This eliminates the need to build auth from scratch.

**Generate with:**
```bash
mix phx.gen.auth Accounts User users --live
```

This creates ~15-20 files including:
- `User` schema (email, hashed_password nullable, confirmed_at)
- `UserToken` schema (hashed tokens, contexts: "session"/"login"/"change:email")
- `Accounts` context with all auth functions
- `Accounts.Scope` module for wrapping current user in assigns
- `UserLive.Login` / `UserLive.Registration` / `UserLive.Confirmation` LiveViews
- `UserSessionController` for session management (magic link POST + logout)
- `UserAuth` plug module with `on_mount` hooks for LiveView auth
- `UserNotifier` for sending magic link emails (uses Swoosh, already configured in the project)
- Migration for `users` and `users_tokens` tables

**Magic link flow (generated by Phoenix):**
1. User enters email on login page
2. System generates a SHA-256-hashed token, stores hash in `users_tokens`, emails the raw token as a URL
3. User clicks the link → lands on confirmation LiveView
4. User clicks "Confirm" → form POSTs to `UserSessionController` which verifies token, creates session
5. Token expires after 15 minutes; token is single-use (deleted on verification)

**Post-generation cleanup (magic-link-only):**
- Remove password fields from the login form (keep magic link only)
- Remove password login in `UserSessionController` + `/users/update-password` route
- Remove signup link (invite-only)
- Optionally keep password fields in DB for future use, but keep UI + controller magic-link-only

### Additional Auth Requirements (Beyond Generator)

1. **User-Brand relationship:** `user_brands` junction table with `role` (owner/admin/viewer)
2. **Brand authorization plug/hook:**
   - `on_mount :set_brand` — resolve brand from URL slug, assign to socket
   - `on_mount :require_brand_access` — verify user has access to the resolved brand
3. **Extend `Accounts.Scope`** to include `current_brand` alongside `current_user`
4. **Invite-only registration:** build invite flow (or admin-only user creation) and create `user_brands` on acceptance
5. **Layouts:** All LiveView templates must start with `<Layouts.app flash={@flash} current_scope={@current_scope} ...>` to avoid `current_scope` errors and comply with Phoenix v1.8 guidelines

---

## 4. Routing Architecture

### Current Routes (Implemented Brand Context)
Dual-mode routing is now implemented in `router.ex` with:

**Default host (path-based):**
```
/b/:brand_slug/products
/b/:brand_slug/products/:id/host
/b/:brand_slug/products/:id/controller
/b/:brand_slug/streams
/b/:brand_slug/creators
/b/:brand_slug/templates/...
```

**Custom domain (host-based, no brand prefix):**
```
/products
/products/:id/host
/products/:id/controller
/streams
/creators
/templates/...
```

**Why dual-mode:**
- Path-based keeps dev/simple default host working
- Custom domains give each brand a clean URL without `/b/:brand_slug`
- Brand context can be resolved from **host or path**, enabling both

### Implementation Pattern (In Router)
```elixir
# router.ex — brand-scoped routes inside an authenticated live_session
live_session :authenticated,
  on_mount: [
    {PavoiWeb.UserAuth, :require_authenticated},
    {PavoiWeb.BrandAuth, :set_brand},
    {PavoiWeb.BrandAuth, :require_brand_access}
  ] do
  # Default host (path-based)
  scope "/b/:brand_slug", PavoiWeb do
    live "/products", ProductsLive.Index
    live "/products/:id/host", ProductHostLive.Index
    live "/streams", TiktokLive.Index
    live "/creators", CreatorsLive.Index
    # ...
  end

  # Custom domains (host-based)
  scope "/", PavoiWeb do
    live "/products", ProductsLive.Index
    live "/products/:id/host", ProductHostLive.Index
    live "/streams", TiktokLive.Index
    live "/creators", CreatorsLive.Index
    # ...
  end
end

# Root "/" redirects to user's default brand
get "/", HomeController, :index
```

### Login → Brand Resolution Flow
1. User clicks magic link → session created → redirected to `/`
2. `PageController.redirect_to_brand` looks up user's brands
3. If one brand → redirect to that brand's **primary domain** (if set), otherwise `/b/:slug/products`
4. If multiple brands → redirect to the default brand (domain if set, otherwise `/b/:slug/products`)
5. If no brands → show "no brands" page or onboarding flow

## 4a. Brand Switcher UX

Users who belong to multiple brands (e.g., "Pavoi Active" and "Pavoi Jewelry") need an elegant way to switch between them without merging data into a single interface.

### Design: Nav Bar Brand Dropdown

A dropdown selector in the nav bar, positioned to the left of the page tabs (Product Sets / Streams / Creators):

```
┌─────────────────────────────────────────────────────────┐
│ [Logo]  [▼ Pavoi Active]  Product Sets | Streams | Creators  [⋮] │
└─────────────────────────────────────────────────────────┘
```

**Behavior:**
- Dropdown shows all brands the user has access to
- Current brand is displayed with a check mark or highlight
- Selecting a different brand navigates to the same page type:
  - If the target brand has a custom domain → navigate to that domain (no `/b/:slug`)
  - Otherwise → navigate to `/b/:brand_slug/...`
  - Example: `/b/pavoi-active/streams` → `https://pavoijewelry.com/streams` (if custom domain set)
- If user only has one brand, the dropdown is hidden (or shown as static text)

**Implementation:**
- The brand list comes from the user's `user_brands` associations, loaded once on mount
- Brand switcher is a component in `nav_tabs` that receives `@current_brand` and `@user_brands`
- Switching brands is a simple `navigate` to the new URL — no state to transfer

**Status:** Implemented in `lib/pavoi_web/components/core_components.ex` (`nav_tabs`).

```elixir
# In nav_tabs component
attr :current_brand, :map, required: true
attr :user_brands, :list, default: []

# Brand switcher dropdown
<div :if={length(@user_brands) > 1} class="relative">
  <button phx-click={toggle_brand_menu()}>
    <%= @current_brand.name %> ▾
  </button>
  <div class="dropdown-menu">
    <.link :for={ub <- @user_brands}
      navigate={brand_switch_path(@current_page, ub.brand)}>
      <%= ub.brand.name %>
    </.link>
  </div>
</div>
```

---

## 5. Hardcoded References

**Multiple occurrences** of "Pavoi"/"pavoi" found (beyond module names):

### Still Hardcoded / Needs Update
| Location | Reference | Fix |
|----------|-----------|-----|
| `config/config.exs` | `default_brand_slug` + `tiktok_live_monitor.accounts: ["pavoi"]` | Keep only for local fallback or move to brand settings |
| `lib/pavoi/tiktok_shop.ex` | `get_auth/1` fallback to slug `"pavoi"` | Require `brand_id` or resolve via settings |
| `lib/pavoi_web/controllers/auth_html/login.html.heex` | "Pavoi" heading | Remove legacy auth template |
| `lib/pavoi_web/controllers/unsubscribe_controller.ex` | HTML titles with "Pavoi" | Make brand-aware (token should include brand_id) |
| `lib/pavoi_web/view_helpers.ex` | Template preview defaults to "Pavoi" | Ensure brand name passed or stored |
| `lib/pavoi/accounts/user_notifier.ex` | From `"Pavoi" <contact@example.com>` | Brand or env-configured sender |
| `lib/pavoi/communications/email.ex` + `config/runtime.exs` | SendGrid from name/email defaults | Move to brand settings |
| `lib/pavoi/workers/*` | default-brand fallbacks (`default_brand_slug`) | Schedule per brand; remove default fallback |
| `lib/pavoi/workers/bigquery_order_sync_worker.ex` | Hardcoded BigQuery project/dataset | Parameterize per brand |

### Already Fixed
- `lib/pavoi/stream_report.ex` now uses `BrandRoutes.brand_url/2`
- `lib/pavoi_web/components/layouts/root.html.heex` uses brand name for `<title>`
- `lib/pavoi_web/components/core_components.ex` uses brand name for logo alt text
- `lib/pavoi_web/live/join_live.ex` uses brand-specific page title and copy when brand is present

### Can Keep (Module Names)
- `Pavoi.*` and `PavoiWeb.*` module prefixes (81 occurrences)
- These are internal namespacing, not user-facing

---

## 6. Recommended Multi-Tenancy Strategy

Based on research of Phoenix best practices:

### Data Isolation: Foreign Key Approach (Recommended)
- Add `brand_id` FK to ALL tables needing isolation
- Scope all queries with `where: [brand_id: ^brand_id]`
- **Not** schema-per-tenant (overkill for this use case)

**Why foreign key approach works:**
- Brand-scoped isolation where needed, while allowing shared creators
- Simpler migrations (one schema, just add FKs)
- Existing pattern partially implemented
- Easier to query across brands for admin purposes if ever needed

### Query Scoping Pattern
```elixir
# In context modules — brand_id is always required (not optional)
def list_products(brand_id) do
  Product
  |> where([p], p.brand_id == ^brand_id)
  |> Repo.all()
end

def list_product_sets_with_details(brand_id) do
  ProductSet
  |> where([ps], ps.brand_id == ^brand_id)
  |> preload([:brand, product_set_products: :product])
  |> Repo.all()
end
```

### PubSub + Oban Namespacing (Critical)
To prevent cross-brand UI updates and job collisions:
- PubSub topics must include brand: `product_sets:#{brand_id}:list`, `tiktok:sync:#{brand_id}`, etc.
- Oban jobs should include `brand_id` in args and uniqueness keys (`unique: [keys: [:brand_id, ...]]`)

### Brand Settings + URL Generation
With custom domains, **all URLs must be brand-aware**:
- Store `primary_domain` (or `base_url`) per brand
- Use brand-aware URL helpers for emails, share links, reports, and redirects
- Update `check_origin` in `config/runtime.exs` to include all brand domains

### LiveView Pattern (Phoenix 1.8 `on_mount` hooks)

Auth and brand resolution happen via `on_mount` hooks declared in the `live_session`, not in individual LiveView `mount/3` functions. By the time a LiveView mounts, `@current_scope` (user) and `@current_brand` are already in assigns.

```elixir
# BrandAuth on_mount hook (new file)
defmodule PavoiWeb.BrandAuth do
  import Phoenix.LiveView
  alias Pavoi.Catalog

  def on_mount(:set_brand, %{"brand_slug" => slug}, _session, socket) do
    brand = Catalog.get_brand_by_slug!(slug)
    {:cont, assign(socket, :current_brand, brand)}
  end

  # Custom domains (no slug in params)
  def on_mount(:set_brand, _params, _session, socket) do
    # Resolve brand by host (e.g., request host -> brand domain mapping)
    brand = Catalog.get_brand_by_domain!(socket.host_uri.host)
    {:cont, assign(socket, :current_brand, brand)}
  end

  def on_mount(:require_brand_access, _params, _session, socket) do
    user = socket.assigns.current_scope.user
    brand = socket.assigns.current_brand

    if Pavoi.Accounts.user_has_brand_access?(user, brand) do
      user_brands = Pavoi.Accounts.list_user_brands(user)
      {:cont, assign(socket, :user_brands, user_brands)}
    else
      {:halt, redirect(socket, to: "/unauthorized")}
    end
  end
end

# Individual LiveViews just use @current_brand — no auth boilerplate
defmodule PavoiWeb.ProductsLive.Index do
  def mount(_params, _session, socket) do
    brand_id = socket.assigns.current_brand.id
    product_sets = ProductSets.list_product_sets_with_details(brand_id)
    {:ok, assign(socket, product_sets: product_sets)}
  end
end
```

---

## 7. Implementation Phases (Recommended Order)

### Phase 0: Multi-Brand Schema Safety (Before Routing Changes)
**Status:** Done (migrations landed Feb 4, 2026)
- Add `brand_id` where missing (streams, comments, stats, outreach_logs, email_templates, message_presets, creator activity tables)
- Add `brand_settings` (or add `brand_id` to `system_settings`)
- Update unique indexes to be **brand-scoped** (products, product_sets, tiktok_streams capturing index)
- Backfill existing Pavoi data with the Pavoi brand_id, then enforce `null: false`

### Phase 1: User Authentication (Magic Links, Invite-Only)
**Status:** Done (magic-link-only, invite-only, legacy auth removed)

Run `mix phx.gen.auth Accounts User users --live` and customize:

**Generated automatically (~15 files):**
- `lib/pavoi/accounts/user.ex` — User schema
- `lib/pavoi/accounts/user_token.ex` — Token schema
- `lib/pavoi/accounts/scope.ex` — Scope wrapper for assigns
- `lib/pavoi/accounts.ex` — Context module
- `lib/pavoi_web/user_auth.ex` — Auth plugs + `on_mount` hooks
- `lib/pavoi_web/live/user_live/login.ex` — Login LiveView (magic link form)
- `lib/pavoi_web/live/user_live/registration.ex` — Registration LiveView (removed for invite-only)
- `lib/pavoi_web/live/user_live/confirmation.ex` — Magic link confirmation
- `lib/pavoi_web/live/user_live/settings.ex` — User settings
- `lib/pavoi_web/controllers/user_session_controller.ex` — Session POST + logout
- `lib/pavoi/accounts/user_notifier.ex` — Email templates (Swoosh)
- Migration: `create_users_auth_tables.exs`
- Test files

**Manual customization:**
- Strip password fields from login form (magic-link-only) — done
- Remove or make optional the "set password" in settings — done
- **Disable public registration** (invite-only UI + routes) — done
- Remove the old `SITE_PASSWORD`-based auth (`require_password.ex`, `auth_controller.ex`, `auth_html/*`) — done
- Update router to use generated auth pipelines instead of `:protected` — done

### Phase 2: User-Brand Relationships + Brand Settings
**Status:** Done (user_brands, invite flow, brand settings UI)

**New migration files:**
```
priv/repo/migrations/
├── YYYYMMDD_create_user_brands.exs          # user_id, brand_id, role
├── YYYYMMDD_add_brand_id_to_creator_activity.exs
├── YYYYMMDD_add_brand_id_to_tiktok_streams.exs
├── YYYYMMDD_add_brand_id_to_outreach_logs.exs
├── YYYYMMDD_add_brand_id_to_email_templates.exs
├── YYYYMMDD_add_brand_id_to_tiktok_shop_auth.exs  # + remove singleton
├── YYYYMMDD_add_brand_id_to_message_presets.exs
└── YYYYMMDD_add_brand_id_to_system_settings.exs     # per-brand config (including custom domains)
```

**New schema:**
```elixir
# lib/pavoi/accounts/user_brand.ex
schema "user_brands" do
  belongs_to :user, Pavoi.Accounts.User
  belongs_to :brand, Pavoi.Catalog.Brand
  field :role, :string  # "owner", "admin", "viewer"
  timestamps()
end
```

**Note:** Brand settings are currently stored in `system_settings` with `brand_id` rather than a separate `brand_settings` table.

**Data migration:** Assign existing Pavoi brand data to the existing brand record; create initial user records for current users.

### Phase 3: Brand Resolution + Custom Domains + Brand Switcher
**Status:** Done (router + BrandAuth + BrandRoutes + nav switcher)
- Add host-based brand resolver (custom domains) + path-based resolver (`/b/:brand_slug`)
- Update URL generation to use brand domains
- Update `check_origin` for WebSockets to allow brand domains
- Add brand switcher that can navigate across domains or `/b/:slug`
- Update LiveView templates to wrap content in `<Layouts.app flash={@flash} current_scope={@current_scope} ...>`

**New files:**
- `lib/pavoi_web/brand_auth.ex` — `on_mount` hooks: `:set_brand`, `:require_brand_access`

**Modify:**
- `lib/pavoi_web/router.ex` — Support both `/b/:brand_slug` and custom-domain scopes in authenticated `live_session`
- `lib/pavoi_web/components/core_components.ex` — Add brand switcher dropdown to `nav_tabs`
- `lib/pavoi_web/live/nav_hooks.ex` — Update to work within brand-scoped routes
- All LiveViews — Read `@current_brand` from assigns (already set by `on_mount`), pass `brand_id` to context functions
- Add root `/` redirect logic (user → default brand)

**Brand switcher component additions to `nav_tabs`:**
- New attrs: `current_brand`, `user_brands`
- Dropdown between logo and page tabs
- Navigates to equivalent page under new brand slug on selection

### Phase 4: Query Scoping + PubSub/Oban Namespacing (Priority Features)
**Status:** Done (brand-scoped queries, topics, and job args for core features)

Focus on Product Sets + Products + Streams first:
- `lib/pavoi/catalog.ex` — Make `brand_id` required on all product queries (not optional)
- `lib/pavoi/product_sets.ex` — Make `brand_id` required on all product set queries
- `lib/pavoi/tiktok_live.ex` — Add `brand_id` to stream queries
- `lib/pavoi/creators.ex` — Use `brand_creators` join for creator scoping; add brand_id to activity tables
- PubSub topics — Namespace by brand: `product_sets:#{brand_id}:list` instead of `product_sets:list`
- Oban jobs — Include `brand_id` in job args and uniqueness keys

### Phase 5: TikTok Shop Multi-Tenant
**Status:** Done (per-brand auth, workers, settings, default-brand fallbacks removed)
- `lib/pavoi/tiktok_shop/auth.ex` — Accept `brand_id`, remove singleton pattern
- `lib/pavoi/tiktok_shop.ex` — Pass `brand_id` to all API calls
- `lib/pavoi/workers/tiktok_token_refresh_worker.ex` — Iterate all brands
- `lib/pavoi/workers/tiktok_sync_worker.ex` — Per-brand execution, remove hardcoded "pavoi" slug
- `lib/pavoi/workers/creator_enrichment_worker.ex` — Remove `get_pavoi_brand_id`, accept brand param
- `lib/pavoi/workers/bigquery_order_sync_worker.ex` — Parameterize project/dataset
- `lib/pavoi/workers/tiktok_live_monitor_worker.ex` — Monitor accounts per brand (not hardcoded list)
- New: TikTok OAuth callback handler that binds to brand via `state` parameter
- Remove default-brand fallbacks in `TiktokShop.get_auth/1` + worker `resolve_brand_id/1`

### Phase 6: Brand Settings & Self-Service Onboarding
**Status:** Done (settings UI, invite flow, brand-aware links)
- Brand settings LiveView at `/b/:brand_slug/settings`
- Per-brand config: email from name, Slack channel, BigQuery dataset, TikTok monitor accounts
- TikTok Shop OAuth connect flow (from settings page)
- Shopify OAuth connect flow (from settings page)
- Invite user to brand flow (email invite → magic link → user_brand created)
- Make outreach/join/unsubscribe links brand-aware (domain + brand context)

---

## 8. Effort Estimate

| Component | Complexity | Files Affected | Notes |
|-----------|------------|----------------|-------|
| Schema Safety + Unique Index Changes (Phase 0) | Medium | 6-10 migrations | Required to avoid cross-brand collisions |
| Magic Link Auth (Phase 1) | **Low** | ~15 generated + ~5 to customize | `phx.gen.auth` does the heavy lifting |
| User-Brand + Brand Settings (Phase 2) | Low-Medium | 1 new schema + 7-9 migrations | Add FKs, brand settings, message presets |
| Brand Resolution + Domains + Switcher (Phase 3) | **Medium** | router.ex, endpoint config, 5+ LiveViews, nav component | Host + path resolution |
| Query Scoping + PubSub/Oban (Phase 4) | Medium | 4+ context modules + workers | Mechanical but touches many files |
| TikTok Shop Multi-tenant (Phase 5) | **High** | 6+ files, new OAuth flow | Critical path — most complex change |
| Brand Settings + Onboarding (Phase 6) | Medium | New LiveView + settings schema | Can be deferred until after core works |
| Hardcoded Strings | Low | ~10-15 files | Cleanup pass |

**Total:** Significant refactor, but achievable incrementally. Phase 1 is dramatically simplified by the Phoenix 1.8 generator — what was previously "build auth from scratch" is now "run a command and customize".

---

## 9. Remaining Considerations

1. **Pricing/Billing:** Any metering or usage tracking needed per brand? (e.g., number of sessions, streams captured)

2. **Admin Access:** Do you (as the platform owner) need a super-admin view to see all brands' data?

3. **Creator Sharing Strategy:** We are keeping shared creators + `brand_creators`. Confirm whether any creator fields should become brand-specific (e.g., notes, status) and migrate accordingly.

4. **TikTok App Approval:** Your TikTok app may need additional approval to support multiple shops. Check TikTok developer portal requirements.

5. **Existing Pavoi Data:** How to handle existing data during migration? Keep as "Pavoi" brand, or something else?

6. **Domain Strategy:** Brands will use custom domains where available; default host remains for others. Confirm DNS/SSL + certificate issuance approach.

7. **Invite-Only Auth:** Decide how invites are created (admin UI vs seed script) and how invite links expire.

---

## 10. Critical Files Summary

### Must Modify (High Priority) — Status as of Feb 2026
| File | Status / Notes |
|------|----------------|
| `lib/pavoi_web/router.ex` | Done (auth + brand scopes in place) |
| `lib/pavoi_web/endpoint.ex` | Verify custom domains + `check_origin` behavior (currently `:conn`) |
| `lib/pavoi_web/components/core_components.ex` | Done (brand switcher in `nav_tabs`) |
| `lib/pavoi_web/live/nav_hooks.ex` | Done |
| `lib/pavoi_web/live/product_sets_live/index.ex` | Done (brand-scoped) |
| `lib/pavoi_web/live/creators_live/index.ex` | Done (brand-scoped) |
| `lib/pavoi_web/live/tiktok_live/index.ex` | Done (brand-scoped) |
| `lib/pavoi_web/live/product_set_host_live/index.ex` | Done (brand validation) |
| `lib/pavoi_web/live/product_set_controller_live/index.ex` | Done (brand validation) |
| `lib/pavoi/catalog.ex` | Done (brand-scoped queries) |
| `lib/pavoi/product_sets.ex` | Done (brand-scoped queries) |
| `lib/pavoi/creators.ex` | Done (brand_creators + brand activity) |
| `lib/pavoi/tiktok_live.ex` | Done (brand-scoped streams) |
| `lib/pavoi/tiktok_shop/auth.ex` | Done (brand_id + per-brand auth) |
| `lib/pavoi/tiktok_shop.ex` | Done (brand-scoped auth + fallback removed) |
| `lib/pavoi/settings.ex` | Done (brand-scoped system_settings) |
| `lib/pavoi/communications/*` | Done (brand-aware URLs + from_email/name) |

### Generated by `phx.gen.auth` (~15 files)
| File | Purpose |
|------|---------|
| `lib/pavoi/accounts/user.ex` | User schema |
| `lib/pavoi/accounts/user_token.ex` | Token schema |
| `lib/pavoi/accounts/scope.ex` | Scope wrapper |
| `lib/pavoi/accounts.ex` | User context module |
| `lib/pavoi_web/user_auth.ex` | Auth plugs + on_mount hooks |
| `lib/pavoi_web/live/user_live/login.ex` | Magic link login |
| `lib/pavoi_web/live/user_live/registration.ex` | Registration (removed for invite-only) |
| `lib/pavoi_web/live/user_live/confirmation.ex` | Magic link confirmation |
| `lib/pavoi_web/controllers/user_session_controller.ex` | Session management |
| `lib/pavoi/accounts/user_notifier.ex` | Email sending |
| Migration: `create_users_auth_tables.exs` | users + users_tokens tables |

### Must Create (New Files — Manual)
| File | Status |
|------|--------|
| `lib/pavoi/accounts/user_brand.ex` | Done |
| `lib/pavoi_web/brand_auth.ex` | Done |
| Migrations for brand_id FKs + user_brands | Done (Feb 2026) |
| Brand settings UI (LiveView) | Done |

### Must Remove
| File | Reason |
|------|--------|
| `lib/pavoi_web/plugs/require_password.ex` | Removed |
| `lib/pavoi_web/controllers/auth_controller.ex` | Removed |
| `lib/pavoi_web/controllers/auth_html/` | Removed |

---

## 11. Bottom Line Assessment

**Is multi-tenancy feasible?** Yes.

**Biggest simplification since initial audit:** Phoenix 1.8's built-in `mix phx.gen.auth` generates magic link authentication out of the box. This turns "build auth from scratch" (previously the #2 challenge) into "run a generator and customize." The project already has Swoosh configured for email delivery.

**Biggest remaining challenges:**
1. Operational onboarding for each brand (TikTok Shop OAuth, Shopify install, BigQuery access, SendGrid domain verification, Slack bot/channel setup)
2. Custom domain DNS + SSL coordination per brand
3. End-to-end validation for each brand (syncs, streams, outreach, order data)

**Risk mitigation:**
- Implement incrementally (don't try to do everything at once)
- Phase 1 (auth) can be deployed independently — it replaces the site password without changing data access patterns
- Phase 0 (schema safety) prevents cross-brand collisions before routing changes
- Phase 2-3 (user-brands + routing + switcher + domains) are the core multi-tenancy enablers
- Phase 4-5 (query scoping + TikTok) complete the isolation
- Keep existing routes working during transition via redirects

**Recommended next steps:** run the onboarding checklist for a new brand end-to-end, confirm custom domain + `check_origin` behavior, and validate data isolation across all core flows.

**Parallel blocker check:** Verify your TikTok developer app can support OAuth for multiple shops. This is a potential blocker for Phase 5 but doesn't block Phases 1-4.

---

## 12. New Brand Onboarding Checklist (Team Request)

Use this checklist when onboarding a new brand. Items marked **(Required)** are blocking; items marked **(If applicable)** depend on which features you want active for the brand.

### TikTok Shop Authorization (Required)

- [ ] **Shop Owner performs OAuth authorization** — The TikTok Shop Owner's main account (not a sub-account or admin) must authorize your app. Sub-accounts cannot authorize third-party services.
- [ ] **Confirm shop region** — Is this a US shop or Global? This determines the authorization URL:
  - US: `https://services.us.tiktokshop.com/open/authorize?service_id=...`
  - Global: `https://services.tiktokshop.com/open/authorize?service_id=...`
- [ ] **Verify app scopes** — Before the shop authorizes, confirm your TikTok Partner Center app has the necessary scopes enabled (at minimum: Shop Authorized Information, Order Information, Product Basic, Affiliate Seller/Marketplace Creators). Scopes are configured at `partner.tiktokshop.com` (or `partner.us.tiktokshop.com` for US).
- [ ] **Verify redirect URL** — Your app's OAuth redirect URL (`/tiktok/callback`) must be registered in the TikTok Partner Center app settings before the shop can authorize.
- [ ] **Send authorization link** — Generate the link with your `service_id` and a `state` parameter encoding the brand. The shop owner clicks it, logs in, and approves.
- [ ] **Confirm tokens received** — After authorization, the system exchanges the returned `auth_code` for `access_token`/`refresh_token` and stores them with the `brand_id`. Verify the token was stored successfully.
- [ ] **Verify shop details** — Call the Get Authorized Shops API (`/authorization/202309/shops`) to retrieve `shop_id`, `shop_cipher`, `shop_name`, and `region`. Confirm correct shop is linked.

### Shopify Store (If applicable — product sync)

- [ ] **Confirm store ownership** — Is the Shopify store in the same Shopify organization as your app? Custom apps can only be installed on stores within the same org. If not, you'll need to use the OAuth authorization-code flow instead of client credentials.
- [ ] **Provide store subdomain** — e.g., `theirbrand.myshopify.com`
- [ ] **Install the Shopify app** — The store admin installs your Shopify app on their store.
- [ ] **Confirm access token** — Store the per-brand Shopify access token. Note: client-credentials tokens expire in ~24 hours and must be refreshed.

### BigQuery (If applicable — order sync / analytics)

- [ ] **Confirm data source** — Is order data in a separate BigQuery project/dataset, or will it be added to the existing Pavoi dataset with brand filtering?
- [ ] **Provide service account access** — If separate project: grant your GCP service account `roles/bigquery.dataViewer` on their dataset. Share the project ID and dataset name.
- [ ] **Confirm table schema** — Verify the BigQuery table structure matches expected schema (`TikTokShopOrders`, `TikTokShopOrderLineItems`), or document any differences.

### SendGrid (If applicable — outreach emails)

- [ ] **Brand-specific sender identity** — Provide the desired `from_name` and `from_email` for outreach emails.
- [ ] **Domain verification** — Verify the sender domain in SendGrid (or use a shared verified domain with a brand-specific from address).

### Slack (If applicable — alerts and notifications)

- [ ] **Brand-specific Slack channel** — Provide the channel ID where alerts should be routed for this brand.
- [ ] **Bot token** — If using a separate workspace, provide the Slack bot token. If using the same workspace, just the channel ID is sufficient.

### Brand Configuration (Internal)

- [ ] **Create brand record** — Add the brand to the `brands` table with `name`, `slug`, and any settings.
- [ ] **Assign users** — Create user-brand relationships in `user_brands` with appropriate roles.
- [ ] **Invite-only access** — Send invite link(s) or create users directly (no public registration).
- [ ] **Configure brand settings** — Set up email from name, Slack channel, BigQuery dataset, and any other brand-specific configuration.
- [ ] **Custom domain** — Add brand domain, configure DNS + SSL, and ensure `check_origin` allows it.
- [ ] **Verify data isolation** — Confirm that all queries, workers, and API calls for this brand are scoped correctly and no data leaks to/from other brands.
- [ ] **Test end-to-end** — Run through product sync, stream monitoring, creator lookup, and order sync for the new brand to confirm everything works.

---

## 13. Sources

### Multi-Tenancy
- [Building Multitenant Applications with Phoenix and Ecto](https://elixirmerge.com/p/building-multitenant-applications-with-phoenix-and-ecto)
- [Setting Up a Multi-tenant Phoenix App](https://blog.appsignal.com/2023/11/21/setting-up-a-multi-tenant-phoenix-app-for-elixir.html)
- [Subdomain-Based Multi-Tenancy in Phoenix](https://alembic.com.au/blog/subdomain-based-multi-tenancy-in-phoenix)
- [Triplex - Database multitenancy for Elixir](https://github.com/ateliware/triplex)
- [Multitenancy in Elixir: Complete Guide](https://www.curiosum.com/blog/multitenancy-in-elixir)

### Magic Link Authentication (Phoenix 1.8)
- [Phoenix 1.8.0 Released — magic link auth by default](https://www.phoenixframework.org/blog/phoenix-1-8-released)
- [mix phx.gen.auth — Phoenix v1.8 Docs](https://hexdocs.pm/phoenix/Mix.Tasks.Phx.Gen.Auth.html)
- [A Visual Tour of Phoenix's Updated Magic Link Authentication](https://mikezornek.com/posts/2025/5/phoenix-magic-link-authentication/)
- [How To Add Magic Link Login to a Phoenix LiveView App](https://johnelmlabs.com/posts/magic-link-auth)
- [Bringing Phoenix Authentication to Life — Fly.io](https://fly.io/phoenix-files/phx-gen-auth/)
