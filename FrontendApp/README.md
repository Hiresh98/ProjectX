# FrontendApp — RBAC Web App

React 19 + TypeScript + **Redux Toolkit + RTK Query** + React Router v7 + **MUI**
SPA for the multi-role RBAC platform. Pairs with `../BackendApp`.

Full system design: [`../docs/RBAC-SYSTEM.md`](../docs/RBAC-SYSTEM.md).

## Getting started

```bash
cp .env.example .env          # VITE_API_BASE_URL → BackendApp (http://localhost:4000/api/v1)
npm install
npm run dev                   # http://localhost:3000
```

Start `../BackendApp` (and seed it) first, then sign in with a seed account
(e.g. `admin@projectx.dev` / `Password123`) to be routed to the matching
dashboard.

## Scripts

`dev` · `build` · `preview` · `typecheck` · `lint` · `format` · `test` ·
`test:watch` · `test:coverage` · `validate` (typecheck + lint + test).

## Architecture

```
src/
├─ app/            App root, providers (Redux + MUI theme), AuthBootstrap, theme
├─ store/          configureStore (makeStore), authSlice, uiSlice, typed hooks
├─ services/       RTK Query baseApi (token inject + refresh-on-401), authApi
├─ routes/         AppRouter + guards (Protected / RoleProtected / PublicOnly)
├─ layouts/        DashboardLayout (dynamic sidebar), AuthLayout
├─ modules/        admin · account-manager · hr · client · auth
├─ components/     ErrorBoundary, PageHeader, StatCard, Placeholder
├─ hooks/          useAuth, usePermissions
├─ constants/      permissions (mirrors backend), menu config
├─ types/          auth types
└─ utils/          getApiErrorMessage
```

### How auth + RBAC works

- **Access token** lives in Redux (memory); **refresh token** is an httpOnly
  cookie. On load, `AuthBootstrap` silently calls `/auth/refresh` to restore
  the session.
- RTK Query's `baseQuery` injects the Bearer token and, on a 401, refreshes
  once (mutex-guarded) and replays the request.
- **Route guards**: `ProtectedRoute` (authenticated) → `RoleProtectedRoute`
  (permission check) → `/403` on failure. Post-login redirect is role-based.
- **Dynamic sidebar**: `MENU_SECTIONS` is filtered by the user's permissions —
  items they can't access are hidden.
- Frontend checks are **UX-only**; the API independently enforces RBAC.

## Testing

Vitest + React Testing Library. Includes a `RoleProtectedRoute` integration
test proving permission-based redirects, plus slice/util unit tests.
