# MetOS — Metabolic Operating System

> From μέθοδος (méthodos) — "a way of pursuit, a systematic path"

> [!WARNING]
> This is an early alpha. Some features are incomplete or under active development.

[![Zig](https://img.shields.io/badge/Zig-0.16--dev-f7a41d?logo=zig&logoColor=white)](https://ziglang.org)
[![Telegram Bot API](https://img.shields.io/badge/Telegram-Bot%20API-26A5E4?logo=telegram&logoColor=white)](https://core.telegram.org/bots/api)
[![Gemini AI](https://img.shields.io/badge/Gemini-3.1%20Flash--Lite-4285F4?logo=google&logoColor=white)](https://ai.google.dev)
[![SQLite](https://img.shields.io/badge/SQLite-3-003B57?logo=sqlite&logoColor=white)](https://www.sqlite.org)
[![React](https://img.shields.io/badge/React-19-61DAFB?logo=react&logoColor=black)](https://react.dev)
[![Docker](https://img.shields.io/badge/Docker-Alpine-2496ED?logo=docker&logoColor=white)](https://hub.docker.com)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

**Precision metabolic tracking with pharmacokinetic modeling — Telegram bot + React dashboard.**

Send a text or voice message describing what you ate — MetOS analyzes it with Gemini AI and tracks calories, macros, purine levels, and hydration in a local SQLite database. A built-in pharmacokinetic model tracks GLP-1 medication absorption, plasma levels, and appetite suppression curves. Browse your data in a real-time web dashboard.

Gout tracking and GLP-1 pharmacokinetics are optional modules — enable only what you need during onboarding. Without them, MetOS is a clean macro tracker.

---

## Features

| Feature | Description |
|---------|-------------|
| **Meal logging** | Send text or voice — AI estimates calories, protein, carbs, fat, fiber |
| **Backdating** | Prefix any meal, water, or weight entry with `YYYY-MM-DD` to log for a past date |
| **Purine tracking** | Classifies meals as low/medium/high purine with mg estimates (optional module) |
| **Gout warnings** | Flags high-purine meals — organ meats, broths, alcohol (optional module) |
| **Pharmacokinetics** | Two-compartment PK model: plasma level, appetite suppression curve, steady-state accumulation (optional module) |
| **Injection tracking** | Dose, site rotation (6 sites), cycle management, due alerts (optional module) |
| **Smart notifications** | Force Feed (high suppression + low protein), Purine Sentry (returning appetite), hydration, fiber/water ratio |
| **Voice messages** | Transcribes audio via Gemini, shows transcript for approval before analysis |
| **Weight tracking** | Log daily weigh-ins with optional notes |
| **Water tracking** | Log extra water intake, see daily totals |
| **Daily stats** | MetOS Status Report with metabolic load, pharma status, system alerts |
| **Goal setting** | Set calorie and protein targets |
| **Undo** | Delete the last logged meal |
| **Intent sniffing** | LLM rejects non-meal messages — no chatbot abuse |
| **Rate limiting** | 50 LLM calls per day — protects API quota |
| **i18n** | English (default) and Polish, both bot and dashboard |
| **Onboarding** | `/start` walks new users through language and module setup |
| **Owner-only** | Single-user bot — rejects unauthorized users |
| **Web dashboard** | React SPA embedded in the server binary — browse meals, stats, weight, injection phase |

## Commands

```
Send text or voice          →  Log and analyze a meal
YYYY-MM-DD meal description →  Log meal for a past date
/weight 95.2 [note]         →  Log weight (supports YYYY-MM-DD prefix)
/water 500                  →  Log water intake in ml (supports YYYY-MM-DD prefix)
/stats [YYYY-MM-DD]         →  MetOS Status Report
/meals [YYYY-MM-DD]         →  List meals for a day
/history                    →  Last 10 weigh-ins
/goal 2000 150              →  Set daily targets (kcal, protein g)
/injection [dose] [site] [note]  →  Log injection (requires GLP-1 module)
/settings                   →  View current settings
/settings reset             →  Reconfigure language and modules
/undo                       →  Delete last meal
/help                       →  Show commands
```

## Voice Message Flow

```
🎤 Voice message
    ↓
📝 "Transcribing..."
    ↓
📋 Transcript displayed
    ↓
┌─────────┬────────┐
│ Approve │  Edit  │
└─────────┴────────┘
    ↓          ↓
 Analyze    Type corrected text → Analyze
    ↓
📊 Nutrition breakdown + DB insert
```

## Onboarding

On first `/start`, MetOS asks:

1. **Language** — English or Polish (bot messages + dashboard)
2. **Gout tracking** — enable purine analysis and gout warnings
3. **GLP-1 tracking** — enable injection tracking, pharmacokinetics, and PK-based notifications

Settings are stored in the database and can be changed with `/settings reset`. When a module is disabled, its features are hidden from both the bot and the dashboard.

## Architecture

```
┌─────────────────────────────────────────────────┐
│                 Docker Compose                   │
│                                                  │
│  ┌──────────────────┐  ┌──────────────────────┐  │
│  │    bot/           │  │    server/            │  │
│  │                   │  │                       │  │
│  │  Telegram Bot API │  │  React 19 Dashboard   │  │
│  │  Gemini AI        │  │  Tailwind CSS 4       │  │
│  │  kinetics.zig     │  │  kinetics.zig         │  │
│  │  strings.zig      │  │  /api/config          │  │
│  │  (writes to DB)   │  │  (reads from DB)      │  │
│  │                   │  │                       │  │
│  │  ~32MB image      │  │  ~27MB image          │  │
│  └────────┬──────────┘  └──────────┬────────────┘  │
│           │                        │               │
│           └────────┬───────────────┘               │
│                    │                                │
│              ┌─────▼─────┐                          │
│              │  SQLite   │                          │
│              │  (shared) │                          │
│              └───────────┘                          │
└─────────────────────────────────────────────────┘
```

| Layer | Technology |
|-------|-----------|
| Language | [Zig 0.16-dev](https://ziglang.org) (master) — zero allocations in hot path, no GC |
| AI | [Gemini 3.1 Flash-Lite](https://ai.google.dev) — meal analysis + audio transcription |
| Database | [SQLite](https://www.sqlite.org) via [zqlite](https://github.com/karlseguin/zqlite) (vendored) |
| Pharmacokinetics | `kinetics.zig` — configurable two-compartment model (tirzepatide default) |
| Bot interface | [Telegram Bot API](https://core.telegram.org/bots/api) — long polling, inline keyboards |
| Dashboard | [React 19](https://react.dev) + [Tailwind CSS 4](https://tailwindcss.com) — embedded in binary via `@embedFile` |
| i18n (bot) | Comptime string tables in `strings.zig` — zero-allocation, compiler-checked |
| i18n (frontend) | [i18next](https://www.i18next.com) + [react-i18next](https://react.i18next.com) with browser language detection |
| Container | [Alpine Linux](https://alpinelinux.org) 3.21 — independent build contexts per service |
| Config | TOML flat key-value file + `user_config` table for runtime settings |

## Pharmacokinetic Model

MetOS includes a configurable PK engine (`kinetics.zig`) for GLP-1 receptor agonists:

```
Drug: Tirzepatide (Mounjaro)
Elimination t½: 120h | Absorption t½: 24h
Appetite suppression: quadratic ramp → exponential decay (effective t½: 72h)
Steady-state: linear superposition of last 5 weekly doses
```

The `Config` struct allows swapping to other GLP-1 agonists (semaglutide, dulaglutide) by changing half-life parameters. Requires the GLP-1 module to be enabled.

## Database Schema

```sql
meals           -- id, meal_date, raw_text, meal_name, calories,
                -- protein_g, carbs_g, fat_g, fiber_g,
                -- protein_density, purine_level, purine_mg,
                -- gout_warning, water_ml, llm_response

weigh_ins       -- id, weigh_date, weight_kg, notes

water_log       -- id, log_date, water_ml

goals           -- id, target_calories, target_protein_g, target_water_ml

injections      -- id, injection_date, dose_mg, site, notes

notification_log -- id, alert_type, triggered_date

user_config     -- id (singleton), locale, gout_tracking, glp1_tracking, onboarded

llm_usage       -- usage_date, count (daily rate limit tracking)

daily_summary   -- VIEW: aggregated meals by date
```

## Setup

### Prerequisites

- [Telegram Bot Token](https://t.me/BotFather) — create a bot, get the token
- [Gemini API Key](https://aistudio.google.com/apikey) — free tier works
- Your Telegram user ID (send `/start` to [@userinfobot](https://t.me/userinfobot))

### Configuration

Bot config:

```bash
cp config.toml.example config.toml
```

```toml
gemini_api_key = "your-gemini-api-key"
telegram_bot_token = "your-telegram-bot-token"
owner_id = 123456789
db_path = "metos.db"
locale = "en"
```

The `locale` field sets the default language before onboarding. After the user completes `/start`, the locale is stored in the database and takes precedence.

Dashboard config:

```bash
cp config.server.toml.example config.server.toml
```

```toml
db_path = "metos.db"
port = 3000
password = "your-password"
```

### Run with Docker Compose (recommended)

```bash
cp docker-compose.yaml.example docker-compose.yaml
# Edit docker-compose.yaml for your environment (ports, volumes, reverse proxy)
docker compose up -d
docker logs -f metos-bot
```

The bot writes to the shared SQLite database, the dashboard reads from it on port 3000.

### Run natively

Requires [Zig master](https://ziglang.org/download/) and [Bun](https://bun.sh) (for frontend build):

```bash
# Bot
cd bot && zig build run

# Server (builds frontend automatically)
cd server && zig build run
```

## Project Structure

```
bot/                              server/
├── Dockerfile                    ├── Dockerfile
├── build.zig                     ├── build.zig
├── build.zig.zon                 ├── build.zig.zon
├── deps/zqlite/                  ├── deps/zqlite/
└── src/                          ├── embedded_ui.zig
    ├── main.zig                  ├── frontend/  (React + Vite + Tailwind)
    ├── config.zig                │   └── src/i18n/ (en.json, pl.json)
    ├── db.zig  (write ops)       └── src/
    ├── kinetics.zig (PK model)       ├── main.zig
    ├── notifications.zig             ├── config.zig
    ├── strings.zig (i18n)            ├── db.zig  (read-only queries)
    ├── strings_notif.zig (i18n)      ├── kinetics.zig (PK model)
    ├── telegram.zig                  └── server.zig
    └── llm.zig
compose.yaml
config.toml.example
config.server.toml.example
```

## License

[Apache 2.0](LICENSE)
