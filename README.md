# Yüküm — Freight Marketplace (iOS + .NET 10 + SQL Server)

[![backend CI](https://github.com/isaanilkoca/yukum/actions/workflows/backend.yml/badge.svg)](https://github.com/isaanilkoca/yukum/actions/workflows/backend.yml)

**Yüküm** ("my load") is an open freight marketplace: a **Shipper** posts a load, **Carriers** bid on it, the shipper accepts one offer,
the job moves through pickup → transit → delivery, and the shipper rates the carrier. It is a native **SwiftUI** app talking to a
**.NET 10 Web API** backed by **Microsoft SQL Server** — designed, built and tested end-to-end as a portfolio project.

> Turkish-language engineering docs (decisions, daily log, code walkthroughs) live in [`docs/`](docs/). The app UI is Turkish.

| | |
|---|---|
| **iOS** | Swift 6 · SwiftUI · MVVM with `@Observable` · protocol-based DI · async/await + actors · Keychain · APNs · CoreLocation · RealityKit |
| **Backend** | .NET 10 · ASP.NET Core Web API · Clean Architecture · CQRS-lite (no MediatR) · EF Core 10 · Repository + Unit of Work · ASP.NET Identity · JWT |
| **Database** | SQL Server 2025 (Docker) · 20 tables · 24 EF Core migrations |
| **Quality** | 449 backend tests (xUnit + Testcontainers, **96.7 % line coverage**) · 193 iOS unit tests (Swift Testing) · 7 XCUITest flows · GitHub Actions CI |
| **Size** | 65 REST endpoints · 30 screens · 24 view models · 136 commits (Oct 25 – Nov 15, 2026) |

---

## 1. Why this exists

My family farms in Mersin. When we ship agricultural supplies, a carrier from Ankara might quote **8–10 units** for a trip that costs
**5** — because if he can't find a load for the way back he drives home empty, so the risk is priced in. Carriers wait in markets for
days looking for a return load. Yüküm puts both sides in one marketplace: shippers get competing offers, carriers fill empty return trips.

## 2. What it does

**Shipper (Yük Veren)**
- Post a load: origin/destination city → district (81 provinces / 973 districts), weight, vehicle type, pickup date, budget
- See every incoming offer with the carrier's rating, vehicle and promised delivery date; sort by 7 criteria; accept / reject
- Live counters on each listing: views, favourites, offers · market reference price for the route
- Follow the job (pickup → in transit → delivered), chat, mutual cancellation, then rate the carrier (1–5 + comment)

**Carrier (Taşımacı)**
- Browse open loads: filter by route, budget, vehicle, date, weight, **"near me" radius**, "fits my vehicles"; sort by newest / price / pickup date / distance
- Bid with a chosen vehicle and an estimated delivery date · favourite loads · "My vehicles" (plate, make, model, year)
- Advance the job stage, chat with the shipper, see decisions instantly via push notifications

**Both**
- Two separate registrations, one login with role selection, **auto-login** (remember me), e-mail verification, forgot password
- Profile with photo, public profiles, notification centre, **report & block** (App Store guideline 1.2), account deletion (KVKK/GDPR)

## 3. Architecture

```
┌──────────────── iOS (SwiftUI) ────────────────┐        ┌──────────────────── .NET 10 Web API ─────────────────────┐
│ View ─► ViewModel ─► Service ─► APIClient  ───┼─HTTPS─►│ Controller ─► Handler (Application) ─► Repository / UoW   │
│  (UI)    (@Observable) (one fn = one endpoint) │  JSON  │   (thin)       (business rules,        (EF Core 10)       │
│                    AuthSession actor (tokens) │        │                 validation)                 │            │
│                    Keychain (refresh token)   │◄─APNs──│ PushWorker (BackgroundService) ◄─ outbox ◄──┤            │
└───────────────────────────────────────────────┘        └─────────────────────────────────────────────┼────────────┘
                                                                                                        ▼
                                                                                         SQL Server 2025 (Docker)
```

**Dependency rule:** `Domain` knows nothing · `Application` knows only `Domain` and declares interfaces · `Infrastructure`
implements them (EF Core, Identity, APNs, e-mail) · `Api` wires everything. Business rules are testable without a database.

**One request, end to end — a carrier places a bid:**
1. `ListingDetailView` → `ListingDetailViewModel.submit()` validates the form locally.
2. `OfferService.create()` → `APIClient.send(.post, "/api/v1/listings/{id}/offers")` adds the Bearer token; on 401 the `AuthSession` actor refreshes **once** (even if five requests fail at the same time) and retries.
3. `OffersController` → `CreateOfferHandler`: FluentValidation → listing open? → carrier owns a complete vehicle? → delivery date within pickup + 90 days? → not blocked by the shipper?
4. Offer + notification row are written **in the same transaction** (outbox) → `PushWorker` sends the APNs push → the shipper taps it → the app deep-links to the offers screen.
5. Any failure returns RFC 7807 **ProblemDetails** with a Turkish message, which the app shows as-is.

## 4. Backend in detail

| Topic | How it's done | Why |
|---|---|---|
| **Layers** | `Domain` / `Application` / `Infrastructure` / `Api` + unit & integration test projects | Rules stay independent of the database and web framework |
| **CQRS-lite** | `ICommandHandler<TCommand,TResult>` / `IQueryHandler<TQuery,TResult>`, auto-registered by reflection; startup fails if two handlers claim one command | Clear read/write split without MediatR (now commercially licensed) |
| **Data access** | EF Core 10, generic `IRepository<T>` + `IUnitOfWork`, special read repositories where SQL matters (search, counters) | Repository pattern as requested; filters compile to a single SQL query |
| **Entities** | `BaseEntity`: `CreatedAt/UpdatedAt` stamped centrally, **soft delete** query filter, `RowVersion` optimistic concurrency | Two shippers accepting at the same moment cannot both win |
| **Validation** | FluentValidation with Turkish messages; one `PasswordPolicy` shared by validator and Identity | Same rule everywhere, field-level errors for the form |
| **Auth** | ASP.NET Identity (PBKDF2), JWT access token (15 min), **rotating refresh token** (30 days, stored hashed, bound to a device ID; reuse of a stolen token revokes the whole family), lockout after 10 failures for 5 min, rate limiting on auth endpoints | Secure "remember me" the way production apps do it |
| **Authorization** | Role policies (Shipper / Carrier / Admin) + ownership checks in handlers; an **authorization-matrix test** fails if any endpoint is accidentally anonymous | Shippers can't bid, carriers can't post, nobody sees others' data |
| **Search** | Dynamic predicate (only filled filters are applied), stable paging, sort by price/date; distance from district centroids (Haversine) | "Near me" without storing user location |
| **Reference price** | Median of completed jobs on the same route + vehicle in the last 180 days; hidden under 3 samples | One outlier can't mislead |
| **Notifications** | Notification row in the same transaction → `PushWorker` → **APNs over HTTP/2** with an ES256 provider token (cached 50 min); dead device tokens are deleted | No "saved but notification lost" inconsistencies |
| **E-mail** | 6-digit codes stored only as SHA-256 hashes; 15-min lifetime, 5 attempts, 60-s resend cooldown; send endpoints never reveal whether an e-mail exists; **Resend** in production, log sink in development (startup refuses the log sink outside Development) | Verification + password reset without leaking accounts |
| **Safety** | Two-way blocks (no chat, no bids, listings hidden), reports with reason/context, mutual job cancellation | App Store guideline 1.2 for user-generated content |
| **Errors & JSON** | Global exception handler → ProblemDetails (400/401/403/404/409/423/429/500); camelCase, enums as strings, UTC ISO-8601 | One contract the iOS client decodes in one place |
| **Docs** | Built-in OpenAPI + **Scalar** UI at `/scalar`; API versioning (`/api/v1`) | Contract-first integration with the app |

## 5. Database

20 tables, 24 migrations: users/roles (Identity), shipper & carrier profiles, vehicles, service cities, refresh tokens, cities & districts
(seeded from a verified JSON of 81 provinces / 973 districts), listings, offers, messages, reviews, favourites, listing views
(one per person per day), notifications, device tokens, user blocks, user reports, verification codes.
Integrity lives in the database too: filtered unique indexes (one active offer per carrier per listing), unique favourite/view/block pairs,
cascade rules, `RowVersion` columns. Annotated schema: [`docs/veri/Sema.sql`](docs/veri/Sema.sql) · guide: [`docs/SQL_Rehberi.md`](docs/SQL_Rehberi.md).

## 6. iOS in detail

| Topic | How it's done |
|---|---|
| **Architecture** | MVVM: `@MainActor @Observable` view models; views contain no networking or session code (audited) |
| **DI** | Every view model depends on a protocol (`OfferServicing`, `AuthServicing`…) with a default real implementation → fakes in tests |
| **Networking** | One generic `APIClient.send<Response>(method, path, query, body)` + `sendNoContent` + multipart `upload`; services are one function per endpoint |
| **Session** | `AuthSession` **actor**: access token in memory, refresh token in **Keychain**, single shared refresh for concurrent 401s, silent restore on launch |
| **Push** | Permission asked after login (after value is shown), APNs token registered per device, tap → deep link to the right list, badge sync |
| **Location** | CoreLocation only when "near me" is switched on; coordinates sent per query, never stored |
| **Design system** | `Palette` (light/dark/system), shared form components, 2D action animations: shipper = box gets taped / cut, carrier = tyre track / unloading |
| **3D** | RealityKit login scene: one cardboard box falls with physics recorded once and replayed identically, then the scene is snapshotted to an image to save battery |
| **Navigation map** | Each folder starts with a `00_Rehber_*.swift` file describing every file, function and endpoint in it |

## 7. Testing & CI

| Suite | What it covers | Count |
|---|---|---|
| Backend unit (xUnit, NSubstitute) | validators, handlers, password/phone rules, median, distance, compatibility | 152 |
| Backend integration (WebApplicationFactory + **Testcontainers SQL Server**) | every endpoint over real HTTP + real database, authorization matrix, concurrency, outbound senders (Resend, APNs) with fake HTTP | 297 |
| iOS unit (Swift Testing) | every view-model function, `AuthSession` concurrency, a **contract test for every service endpoint** (method + path + query + body) | 193 |
| iOS UI (XCUITest) | empty login, forgot password, registration checks, terms of use, wrong password, login → profile → logout, relaunch auto-login | 7 |

Backend line coverage: **96.7 %**. GitHub Actions builds, runs both backend suites against a disposable SQL Server and builds the Docker image on every push.

## 8. How it was built (step by step)

The project followed a written plan ([`docs/Yukum_Adim_Adim_Uygulama_Plani.pdf`](docs/Yukum_Adim_Adim_Uygulama_Plani.pdf)) and a technical report
([`docs/Yukum_Teknik_Rapor.pdf`](docs/Yukum_Teknik_Rapor.pdf)) in vertical slices: **database → repository → handler → controller → Scalar check → tests → iOS model → view model → view → device test → commit.**

| Stage | Delivered |
|---|---|
| A · Setup | .NET 10 SDK, SQL Server in Docker, repo layout, naming |
| B · Backend foundation | 4-project solution, ProblemDetails, Serilog, `/api/v1`, user-secrets, `BaseEntity`, health check, repository/UoW, handler pipeline |
| C · First connection | provinces/districts tables + verified seed, cached endpoints, iOS `APIClient` |
| D · Identity | two registrations, login + lockout, refresh-token rotation, role policies, rate limiting, Keychain auto-login |
| E · Listings | create/edit/cancel, carrier search with filters, sorting and paging |
| F · Offers (MVP) | bid, accept/reject with concurrency safety, my offers, history |
| G · Jobs & ratings | job stages, completion, reviews, carrier/shipper profiles |
| H · Engagement | favourites, unique daily views, owner counters |
| I · Notifications | in-app notification centre, outbox + APNs push on a real device, deep links |
| J · Location & price | "near me" radius, reference price |
| K · Hardening | account deletion (anonymisation), report & block, terms of use, e-mail verification, forgot password, privacy manifest, CI |
| L · Polish | design system, dark mode, animations, vehicles, chat, mutual cancellation, profile page |

Every decision is recorded in [`docs/Karar_Kayitlari.md`](docs/Karar_Kayitlari.md) (K-001…K-024) and every step in [`docs/Ilerleme_Gunlugu.md`](docs/Ilerleme_Gunlugu.md).

## 9. Project structure

```
backend/
  src/Yukum.Domain           entities and enums (no dependencies)
  src/Yukum.Application      handlers, validators, contracts, interfaces
  src/Yukum.Infrastructure   EF Core, Identity, JWT, e-mail, APNs, migrations, seed
  src/Yukum.Api              controllers, middleware, background push worker, Program.cs
  tests/                     Yukum.UnitTests · Yukum.IntegrationTests
ios/Yukum/
  Yukum/App · Design · Models (Auth, Listings, Offers, Chat, Notifications, Geography, Vehicles,
         Services + Protocols, Networking, Security, Location) · ViewModels · Views
  YukumTests · YukumUITests
docs/                        report, plan, decisions, daily log, backend/SQL/e-mail guides, API cards
```

## 10. Run it

**Everything in Docker (one command)** — needs Docker Desktop. Tables and the 81-province seed are created on startup.
```bash
cp .env.example .env          # set DB_PASSWORD and JWT_SIGNING_KEY (.env is git-ignored)
docker compose up --build
```
API docs: http://localhost:5054/scalar · health: http://localhost:5054/health · the iOS simulator build points at `localhost:5054`.

**Development setup** — .NET 10 SDK, Docker Desktop, Xcode 26:
```bash
docker run -d --name yukum-sql --platform linux/amd64 -e ACCEPT_EULA=Y -e "MSSQL_SA_PASSWORD=<strong-password>" \
  -e MSSQL_PID=Developer -p 1433:1433 -v yukum-sql-data:/var/opt/mssql mcr.microsoft.com/mssql/server:2025-latest

dotnet user-secrets set "ConnectionStrings:DefaultConnection" "Server=localhost,1433;Database=Yukum;User Id=yukum_app;Password=<pw>;TrustServerCertificate=True;Encrypt=True" --project backend/src/Yukum.Api
dotnet user-secrets set "Jwt:SigningKey" "$(openssl rand -base64 48)" --project backend/src/Yukum.Api
# optional: real e-mail — dotnet user-secrets set "Email:ResendApiKey" "<key>" --project backend/src/Yukum.Api

cd backend && dotnet tool restore && dotnet ef database update --project src/Yukum.Infrastructure --startup-project src/Yukum.Api
dotnet run --project src/Yukum.Api --launch-profile http
dotnet test Yukum.slnx           # integration tests start their own SQL Server container
```
Then open `ios/Yukum/Yukum.xcodeproj` and run. Secrets never enter the repository (user-secrets locally, environment variables in production).

## 11. Status & roadmap

Feature-complete and running end to end on a real iPhone against the local API. Not yet done, by choice: public hosting (server, domain, HTTPS),
an admin panel for reviewing reports, TestFlight / App Store submission, OpenTelemetry tracing, Bayesian rating score.

## 12. Documentation (Turkish)

- [`docs/Backend_Rehberi.md`](docs/Backend_Rehberi.md) — folder map, every endpoint with its role, naming rules, commands
- [`docs/Kod_Anlatimi.md`](docs/Kod_Anlatimi.md) — how to read the code: three real requests traced file by file
- [`docs/Eposta_Sistemi.md`](docs/Eposta_Sistemi.md) — e-mail verification and password reset
- [`docs/SQL_Rehberi.md`](docs/SQL_Rehberi.md) · [`docs/sql/`](docs/sql/) — schema and ready-made queries
- [`docs/api/`](docs/api/) — API contract cards · live docs at `/scalar`
- [`docs/Karar_Kayitlari.md`](docs/Karar_Kayitlari.md) · [`docs/Ilerleme_Gunlugu.md`](docs/Ilerleme_Gunlugu.md) — decisions and daily log

---
Built by **İsa Anıl Koca** · [Portfolio](https://isaanilkoca.github.io) · [GitHub](https://github.com/isaanilkoca)
