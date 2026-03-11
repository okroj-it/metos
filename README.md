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

Send a text or voice message describing what you ate — MetOS analyzes it with Gemini AI and tracks calories, macros, purine levels, and hydration in a local SQLite database. A built-in pharmacokinetic model tracks GLP-1 medication absorption, plasma levels, and appetite suppression curves. Browse your data in a real-time web dashboard. Built for people on GLP-1 medications (Mounjaro, Ozempic) who need to monitor protein intake, gout triggers, and injection cycles.

---

## Features

| Feature | Description |
|---------|-------------|
| **Meal logging** | Send text or voice — AI estimates calories, protein, carbs, fat, fiber |
| **Purine tracking** | Classifies meals as low/medium/high purine with mg estimates |
| **Gout warnings** | Flags high-purine meals (organ meats, broths, alcohol) |
| **Pharmacokinetics** | Two-compartment PK model: plasma level, appetite suppression curve, steady-state accumulation |
| **Injection tracking** | Dose, site rotation (6 sites), cycle management, due alerts |
| **Smart notifications** | Force Feed (high suppression + low protein), Purine Sentry (returning appetite), hydration, fiber/water ratio |
| **Voice messages** | Transcribes audio via Gemini, shows transcript for approval before analysis |
| **Weight tracking** | Log daily weigh-ins with optional notes |
| **Water tracking** | Log extra water intake, see daily totals |
| **Daily stats** | MetOS Status Report with metabolic load, pharma status, system alerts |
| **Goal setting** | Set calorie and protein targets |
| **Undo** | Delete the last logged meal |
| **Owner-only** | Single-user bot — rejects unauthorized users |
| **Web dashboard** | React SPA embedded in the server binary — browse meals, stats, weight, injection phase |

## Commands

```
Send text or voice    →  Log and analyze a meal
/weight 95.2 [note]   →  Log weight
/water 500            →  Log water intake (ml)
/stats [YYYY-MM-DD]   →  MetOS Status Report
/meals [YYYY-MM-DD]   →  List meals for a day
/history              →  Last 10 weigh-ins
/goal 2000 150        →  Set daily targets (kcal, protein g)
/injection [dose] [site] [note]  →  Log injection
/undo                 →  Delete last meal
/help                 →  Show commands
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
| Container | [Alpine Linux](https://alpinelinux.org) 3.21 — independent build contexts per service |
| Config | TOML flat key-value file |

## Pharmacokinetic Model

MetOS includes a configurable PK engine (`kinetics.zig`) for GLP-1 receptor agonists:

```
Drug: Tirzepatide (Mounjaro)
Elimination t½: 120h | Absorption t½: 24h
Appetite suppression: quadratic ramp → exponential decay (effective t½: 72h)
Steady-state: linear superposition of last 5 weekly doses
```

The `Config` struct allows swapping to other GLP-1 agonists (semaglutide, dulaglutide) by changing half-life parameters.

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

daily_summary   -- VIEW: aggregated meals by date
```

## Setup

### Prerequisites

- [Telegram Bot Token](https://t.me/BotFather) — create a bot, get the token
- [Gemini API Key](https://aistudio.google.com/apikey) — free tier works
- Your Telegram user ID (send `/start` to [@userinfobot](https://t.me/userinfobot))

### BotFather Setup

After creating your bot with [@BotFather](https://t.me/BotFather), send `/setcommands` and paste:

```
stats - Daily nutrition summary
meals - List meals for a day
history - Last 10 weigh-ins
weight - Log weight
water - Log water intake
goal - Set calorie and protein targets
injection - Log Mounjaro injection
undo - Delete last meal
help - Show commands
```

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
```

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
    ├── config.zig                └── src/
    ├── db.zig  (write ops)           ├── main.zig
    ├── kinetics.zig (PK model)       ├── config.zig
    ├── notifications.zig             ├── db.zig  (read-only queries)
    ├── telegram.zig                  ├── kinetics.zig (PK model)
    └── llm.zig                       └── server.zig
compose.yaml
config.toml.example
config.server.toml.example
```

## License

[Apache 2.0](LICENSE)
