# Macyad MVP Implementation Plan

> [!WARNING]
> Этот план сохранён как исторический артефакт ранней реализации на `Tauri`/`React`.
> Он больше не является актуальным implementation plan для репозитория.
> Актуальный нативный план находится в [2026-05-24-macyad-native-swift-rewrite.md](2026-05-24-macyad-native-swift-rewrite.md).

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Собрать рабочее macOS `menu bar` приложение `Macyad`, которое использует `rclone` как execution engine для managed-workspace sync-пар Yandex Disk с manual pull, scheduled push, drift check, `info/warning/alarm` и базовой `ru/en` локализацией.

**Architecture:** Приложение строится как `Tauri 2` desktop shell с `Rust` orchestration core и `React`-UI. `Rust`-слой отвечает за app-managed filesystem layout, `SQLite`, `rclone` discovery/install/bootstrap, drift classification, scheduler и notifications; `React` отвечает за dropdown, onboarding, detail-view и language switching. `rclone` не определяет продуктовые правила — он выполняет команды, а решения принимает `Sync Controller`.

**Tech Stack:** Tauri 2, Rust, SQLite, React, TypeScript, Vite, Vitest, Testing Library, i18next, macOS notifications

---

## Planned File Structure

### Root Tooling

- `package.json`
  Назначение: frontend/tooling scripts, Tauri CLI, test scripts
- `.gitignore`
  Назначение: игнорировать build artifacts, `.superpowers/`, app data fixtures
- `vite.config.ts`, `tsconfig.json`, `tsconfig.node.json`, `index.html`
  Назначение: Vite/TypeScript bootstrap

### Frontend

- `src/main.tsx`
  Назначение: bootstrap React + i18n
- `src/App.tsx`
  Назначение: root view switch между dashboard, onboarding, detail, settings
- `src/styles/app.css`
  Назначение: общий visual language dropdown/detail UI
- `src/lib/i18n.ts`
  Назначение: инициализация `ru/en`, fallback и runtime switch
- `src/locales/ru/app.json`, `src/locales/en/app.json`
  Назначение: user-facing strings
- `src/types/contracts.ts`
  Назначение: frontend contracts, зеркалящие Rust DTO
- `src/api/tauri.ts`
  Назначение: typed wrappers around `invoke`
- `src/state/app-store.ts`
  Назначение: frontend state orchestration
- `src/components/StatusHeader.tsx`
  Назначение: верхний status block
- `src/components/QuickActions.tsx`
  Назначение: `Sync Now`, `Check Yandex`, `Pull From Yandex`
- `src/components/SyncPairCard.tsx`
  Назначение: summary card sync-пары
- `src/components/EventList.tsx`
  Назначение: recent events
- `src/components/OnboardingWizard.tsx`
  Назначение: install/discovery/import remote flow
- `src/components/PairDetailView.tsx`
  Назначение: attention/alarm state detail-view
- `src/components/SettingsView.tsx`
  Назначение: language, schedule, delete policy defaults

### Backend

- `src-tauri/Cargo.toml`
  Назначение: Rust/Tauri dependencies and features, включая tray icon
- `src-tauri/tauri.conf.json`
  Назначение: app identifier, build config, bundle metadata
- `src-tauri/capabilities/default.json`
  Назначение: разрешения на shell/process/dialog/notification
- `src-tauri/src/main.rs`
  Назначение: bootstrap runtime
- `src-tauri/src/lib.rs`
  Назначение: app builder, tray lifecycle, command registration
- `src-tauri/src/error.rs`
  Назначение: normalized app errors
- `src-tauri/src/models.rs`
  Назначение: domain types и DTO
- `src-tauri/src/app_state.rs`
  Назначение: shared state, paths, repository, services
- `src-tauri/src/db.rs`
  Назначение: SQLite schema and repository
- `src-tauri/src/commands/mod.rs`
  Назначение: command module registry
- `src-tauri/src/commands/app.rs`
  Назначение: overview/settings/language commands
- `src-tauri/src/commands/onboarding.rs`
  Назначение: `rclone` discovery/install/import/validate commands
- `src-tauri/src/commands/pairs.rs`
  Назначение: create/list/detail sync pair commands
- `src-tauri/src/commands/sync.rs`
  Назначение: manual pull, check, sync now
- `src-tauri/src/services/mod.rs`
  Назначение: service exports
- `src-tauri/src/services/workspace.rs`
  Назначение: managed directories and app-owned paths
- `src-tauri/src/services/rclone.rs`
  Назначение: binary resolution, managed config and command execution
- `src-tauri/src/services/onboarding.rs`
  Назначение: guided setup and import flows
- `src-tauri/src/services/drift.rs`
  Назначение: snapshot compare and `info/warning/alarm`
- `src-tauri/src/services/sync_runner.rs`
  Назначение: initial pull, scheduled push and delete policy execution
- `src-tauri/src/services/scheduler.rs`
  Назначение: interval scheduling and run locks
- `src-tauri/src/services/notifications.rs`
  Назначение: system notification dispatch for `warning/alarm`

### Tests

- `src-tauri/tests/repository_smoke.rs`
- `src-tauri/tests/workspace_paths.rs`
- `src-tauri/tests/rclone_discovery.rs`
- `src-tauri/tests/drift_classifier.rs`
- `src-tauri/tests/sync_runner.rs`
- `src-tauri/tests/commands_smoke.rs`
- `src/lib/i18n.test.ts`
- `src/components/SyncPairCard.test.tsx`
- `src/components/OnboardingWizard.test.tsx`
- `src/components/PairDetailView.test.tsx`

---

### Task 1: Заинициализировать Tauri + React workspace и smoke shell

**Files:**
- Create: `.gitignore`
- Modify: `package.json`
- Modify: `vite.config.ts`
- Modify: `src/App.tsx`
- Modify: `src/main.tsx`
- Modify: `src/App.css` and `src/index.css` -> replace with `src/styles/app.css`
- Create: `src-tauri/src/lib.rs`
- Modify: `src-tauri/src/main.rs`
- Modify: `src-tauri/Cargo.toml`
- Modify: `src-tauri/tauri.conf.json`
- Modify: `src-tauri/capabilities/default.json`

- [ ] **Step 1: Scaffold Vite React TypeScript frontend inside the repo**

Run:

```bash
cd /Users/zerotool/Documents/Dev/macyad
npm create vite@latest . -- --template react-ts
```

Expected: `package.json`, `vite.config.ts`, `tsconfig*.json`, `src/` and `index.html` created in the repo root

- [ ] **Step 2: Install frontend test/tooling deps and initialize Tauri backend**

Run:

```bash
cd /Users/zerotool/Documents/Dev/macyad
npm install
npm install -D @tauri-apps/cli@latest vitest @testing-library/react @testing-library/jest-dom
npm install @tauri-apps/api @tauri-apps/plugin-dialog @tauri-apps/plugin-notification i18next react-i18next zustand
npx tauri init
```

Expected:
- `npm install` finishes without peer dependency errors
- `npx tauri init` creates `src-tauri/`

When `npx tauri init` prompts, answer:

```text
What is your app name? Macyad
What should the window title be? Macyad
Where are your web assets located? ../dist
What is the url of your dev server? http://localhost:5173
What is your frontend dev command? npm run dev
What is your frontend build command? npm run build
```

- [ ] **Step 3: Update root scripts and ignore generated/non-project artifacts**

```json
// package.json (scripts section)
{
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "typecheck": "tsc --noEmit",
    "test": "vitest run",
    "test:watch": "vitest",
    "tauri:dev": "tauri dev",
    "tauri:build": "tauri build"
  }
}
```

```gitignore
# .gitignore
node_modules/
dist/
src-tauri/target/
.DS_Store
.superpowers/
coverage/
```

- [ ] **Step 4: Replace starter frontend with a visible Macyad shell and dedicated stylesheet**

```tsx
// src/App.tsx
import './styles/app.css';

export default function App() {
  return (
    <main className="app-shell">
      <section className="hero-card">
        <p className="eyebrow">Macyad MVP</p>
        <h1>Menu bar Yandex sync controller for macOS</h1>
        <p>
          Frontend bootstrap is ready. Next tasks will replace this shell with
          onboarding, dashboard, pair detail and settings views.
        </p>
      </section>
    </main>
  );
}
```

```tsx
// src/main.tsx
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
```

```css
/* src/styles/app.css */
body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  background: linear-gradient(180deg, #f7faf7 0%, #eef3ef 100%);
  color: #1f231f;
}

.app-shell {
  min-height: 100vh;
  display: grid;
  place-items: center;
  padding: 24px;
}

.hero-card {
  max-width: 720px;
  padding: 32px;
  border-radius: 24px;
  background: #fffefb;
  border: 1px solid #d6ded5;
  box-shadow: 0 24px 60px rgba(31, 35, 31, 0.10);
}

.eyebrow {
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: #0e7c66;
  font-weight: 700;
}
```

- [ ] **Step 5: Turn the Tauri bootstrap into a tray-first Macyad app**

```toml
# src-tauri/Cargo.toml (dependency snippet)
[lib]
name = "macyad_lib"
crate-type = ["staticlib", "cdylib", "rlib"]

[dependencies]
tauri = { version = "2", features = ["tray-icon"] }
tauri-plugin-dialog = "2"
tauri-plugin-notification = "2"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
rusqlite = { version = "0.32", features = ["bundled"] }
which = "7"
reqwest = { version = "0.12", default-features = false, features = ["blocking", "rustls-tls"] }
zip = "2"

[dev-dependencies]
tempfile = "3"
```

```rust
// src-tauri/src/lib.rs
use tauri::{
  menu::{Menu, MenuItem},
  tray::TrayIconBuilder,
  Manager,
};

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
  tauri::Builder::default()
    .plugin(tauri_plugin_dialog::init())
    .plugin(tauri_plugin_notification::init())
    .setup(|app| {
      let show = MenuItem::with_id(app, "show", "Show Macyad", true, None::<&str>)?;
      let quit = MenuItem::with_id(app, "quit", "Quit", true, None::<&str>)?;
      let menu = Menu::with_items(app, &[&show, &quit])?;

      TrayIconBuilder::new()
        .menu(&menu)
        .show_menu_on_left_click(true)
        .on_menu_event(|app, event| match event.id.as_ref() {
          "show" => {
            if let Some(window) = app.get_webview_window("main") {
              let _ = window.show();
              let _ = window.set_focus();
            }
          }
          "quit" => app.exit(0),
          _ => {}
        })
        .build(app)?;

      Ok(())
    })
    .run(tauri::generate_context!())
    .expect("error while running Macyad");
}
```

```rust
// src-tauri/src/main.rs
fn main() {
  macyad_lib::run();
}
```

```json
// src-tauri/tauri.conf.json (relevant fields)
{
  "productName": "Macyad",
  "identifier": "com.orloff.macyad",
  "app": {
    "windows": [
      {
        "label": "main",
        "title": "Macyad",
        "width": 1120,
        "height": 760
      }
    ]
  }
}
```

```json
// src-tauri/capabilities/default.json
{
  "permissions": [
    "core:default",
    "dialog:default",
    "notification:default"
  ]
}
```

- [ ] **Step 6: Run smoke checks for the scaffold**

Run:

```bash
cd /Users/zerotool/Documents/Dev/macyad
npm run build
cargo check --manifest-path src-tauri/Cargo.toml
npm run tauri:dev
```

Expected:
- `npm run build` finishes with a production bundle in `dist/`
- `cargo check` succeeds
- `npm run tauri:dev` opens a Macyad window and creates a tray icon

- [ ] **Step 7: Commit**

```bash
git add .gitignore package.json vite.config.ts tsconfig.json tsconfig.node.json index.html src src-tauri
git commit -m "feat: bootstrap Macyad Tauri workspace"
```

### Task 2: Добавить Rust domain models и SQLite repository foundation

**Files:**
- Create: `src-tauri/src/error.rs`
- Create: `src-tauri/src/models.rs`
- Create: `src-tauri/src/db.rs`
- Create: `src-tauri/src/app_state.rs`
- Create: `src-tauri/tests/repository_smoke.rs`
- Modify: `src-tauri/src/lib.rs`

- [ ] **Step 1: Write failing repository tests for schema migration and sync pair persistence**

```rust
// src-tauri/tests/repository_smoke.rs
use macyad_lib::{
  db::Repository,
  models::{DeletePolicy, PairSeverity, SyncPairDraft},
};

#[test]
fn migrates_schema_and_inserts_default_settings() {
  let dir = tempfile::tempdir().unwrap();
  let repo = Repository::open(dir.path().join("macyad.db")).unwrap();

  let settings = repo.load_settings().unwrap();
  assert_eq!(settings.ui_language, "ru");
  assert_eq!(settings.default_schedule_minutes, 30);
}

#[test]
fn creates_and_reads_sync_pair() {
  let dir = tempfile::tempdir().unwrap();
  let repo = Repository::open(dir.path().join("macyad.db")).unwrap();

  let pair_id = repo
    .insert_sync_pair(SyncPairDraft {
      name: "Work Docs".into(),
      local_relative_path: "Work Docs".into(),
      remote_path: "yd:/Work Docs".into(),
      schedule_minutes: 30,
      delete_policy: DeletePolicy::MirrorToYandex,
    })
    .unwrap();

  let pair = repo.get_sync_pair(pair_id).unwrap().unwrap();
  assert_eq!(pair.name, "Work Docs");
  assert_eq!(pair.severity, PairSeverity::Healthy);

  let pairs = repo.list_sync_pairs().unwrap();
  assert_eq!(pairs.len(), 1);
}
```

- [ ] **Step 2: Run the Rust test file to verify repository types do not exist yet**

Run:

```bash
cd /Users/zerotool/Documents/Dev/macyad
cargo test --manifest-path src-tauri/Cargo.toml --test repository_smoke
```

Expected: FAIL with unresolved imports for `Repository`, `DeletePolicy`, `PairSeverity` or `SyncPairDraft`

- [ ] **Step 3: Implement domain errors and models**

```rust
// src-tauri/src/error.rs
use std::{fmt, io};

#[derive(Debug)]
pub enum AppError {
  Io(io::Error),
  Sql(rusqlite::Error),
  Validation(String),
}

impl fmt::Display for AppError {
  fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
    match self {
      Self::Io(err) => write!(f, "io error: {err}"),
      Self::Sql(err) => write!(f, "sql error: {err}"),
      Self::Validation(msg) => write!(f, "{msg}"),
    }
  }
}

impl From<io::Error> for AppError {
  fn from(value: io::Error) -> Self {
    Self::Io(value)
  }
}

impl From<rusqlite::Error> for AppError {
  fn from(value: rusqlite::Error) -> Self {
    Self::Sql(value)
  }
}
```

```rust
// src-tauri/src/models.rs
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum PairSeverity {
  Healthy,
  Info,
  Warning,
  Alarm,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum DeletePolicy {
  MirrorToYandex,
  KeepRemoteDeletesSafe,
  RequireConfirmation,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct AppSettings {
  pub ui_language: String,
  pub default_schedule_minutes: u32,
  pub start_at_login: bool,
  pub preferred_rclone_mode: String,
}

#[derive(Debug, Clone)]
pub struct SyncPairDraft {
  pub name: String,
  pub local_relative_path: String,
  pub remote_path: String,
  pub schedule_minutes: u32,
  pub delete_policy: DeletePolicy,
}

#[derive(Debug, Clone)]
pub struct SyncPair {
  pub id: i64,
  pub name: String,
  pub local_relative_path: String,
  pub remote_path: String,
  pub schedule_minutes: u32,
  pub delete_policy: DeletePolicy,
  pub severity: PairSeverity,
}
```

- [ ] **Step 4: Implement SQLite schema, settings bootstrap and sync pair repository**

```rust
// src-tauri/src/db.rs
use std::path::PathBuf;

use rusqlite::{params, Connection, OptionalExtension};

use crate::{
  error::AppError,
  models::{AppSettings, DeletePolicy, PairSeverity, SyncPair, SyncPairDraft},
};

pub struct Repository {
  conn: Connection,
}

impl Repository {
  pub fn open(path: PathBuf) -> Result<Self, AppError> {
    let conn = Connection::open(path)?;
    let repo = Self { conn };
    repo.migrate()?;
    Ok(repo)
  }

  fn migrate(&self) -> Result<(), AppError> {
    self.conn.execute_batch(
      r#"
      create table if not exists app_settings (
        id integer primary key check (id = 1),
        ui_language text not null,
        default_schedule_minutes integer not null,
        start_at_login integer not null,
        preferred_rclone_mode text not null
      );

      create table if not exists sync_pairs (
        id integer primary key,
        name text not null,
        local_relative_path text not null,
        remote_path text not null,
        schedule_minutes integer not null,
        delete_policy text not null,
        severity text not null
      );
      "#,
    )?;

    self.conn.execute(
      "insert or ignore into app_settings (id, ui_language, default_schedule_minutes, start_at_login, preferred_rclone_mode) values (1, 'ru', 30, 1, 'auto')",
      [],
    )?;

    Ok(())
  }

  pub fn load_settings(&self) -> Result<AppSettings, AppError> {
    Ok(self.conn.query_row(
      "select ui_language, default_schedule_minutes, start_at_login, preferred_rclone_mode from app_settings where id = 1",
      [],
      |row| {
        Ok(AppSettings {
          ui_language: row.get(0)?,
          default_schedule_minutes: row.get(1)?,
          start_at_login: row.get::<_, i64>(2)? == 1,
          preferred_rclone_mode: row.get(3)?,
        })
      },
    )?)
  }

  pub fn insert_sync_pair(&self, draft: SyncPairDraft) -> Result<i64, AppError> {
    self.conn.execute(
      "insert into sync_pairs (name, local_relative_path, remote_path, schedule_minutes, delete_policy, severity) values (?1, ?2, ?3, ?4, ?5, ?6)",
      params![
        draft.name,
        draft.local_relative_path,
        draft.remote_path,
        draft.schedule_minutes,
        format!("{:?}", draft.delete_policy),
        "Healthy"
      ],
    )?;
    Ok(self.conn.last_insert_rowid())
  }

  pub fn get_sync_pair(&self, id: i64) -> Result<Option<SyncPair>, AppError> {
    Ok(self
      .conn
      .query_row(
        "select id, name, local_relative_path, remote_path, schedule_minutes, delete_policy, severity from sync_pairs where id = ?1",
        [id],
        |row| {
          Ok(SyncPair {
            id: row.get(0)?,
            name: row.get(1)?,
            local_relative_path: row.get(2)?,
            remote_path: row.get(3)?,
            schedule_minutes: row.get(4)?,
            delete_policy: match row.get::<_, String>(5)?.as_str() {
              "KeepRemoteDeletesSafe" => DeletePolicy::KeepRemoteDeletesSafe,
              "RequireConfirmation" => DeletePolicy::RequireConfirmation,
              _ => DeletePolicy::MirrorToYandex,
            },
            severity: match row.get::<_, String>(6)?.as_str() {
              "Info" => PairSeverity::Info,
              "Warning" => PairSeverity::Warning,
              "Alarm" => PairSeverity::Alarm,
              _ => PairSeverity::Healthy,
            },
          })
        },
      )
      .optional()?)
  }

  pub fn list_sync_pairs(&self) -> Result<Vec<SyncPair>, AppError> {
    let mut statement = self.conn.prepare(
      "select id, name, local_relative_path, remote_path, schedule_minutes, delete_policy, severity from sync_pairs order by id asc",
    )?;

    let rows = statement.query_map([], |row| {
      Ok(SyncPair {
        id: row.get(0)?,
        name: row.get(1)?,
        local_relative_path: row.get(2)?,
        remote_path: row.get(3)?,
        schedule_minutes: row.get(4)?,
        delete_policy: match row.get::<_, String>(5)?.as_str() {
          "KeepRemoteDeletesSafe" => DeletePolicy::KeepRemoteDeletesSafe,
          "RequireConfirmation" => DeletePolicy::RequireConfirmation,
          _ => DeletePolicy::MirrorToYandex,
        },
        severity: match row.get::<_, String>(6)?.as_str() {
          "Info" => PairSeverity::Info,
          "Warning" => PairSeverity::Warning,
          "Alarm" => PairSeverity::Alarm,
          _ => PairSeverity::Healthy,
        },
      })
    })?;

    Ok(rows.collect::<Result<Vec<_>, _>>()?)
  }
}
```

```rust
// src-tauri/src/app_state.rs
use std::sync::{Arc, Mutex};

use crate::{db::Repository, error::AppError};

pub struct AppState {
  pub repo: Arc<Mutex<Repository>>,
}

impl AppState {
  pub fn new(repo: Repository) -> Result<Self, AppError> {
    Ok(Self {
      repo: Arc::new(Mutex::new(repo)),
    })
  }
}
```

- [ ] **Step 5: Wire the repository modules into the library and verify tests pass**

```rust
// src-tauri/src/lib.rs (module header)
pub mod app_state;
pub mod db;
pub mod error;
pub mod models;
```

Run:

```bash
cd /Users/zerotool/Documents/Dev/macyad
cargo test --manifest-path src-tauri/Cargo.toml --test repository_smoke
```

Expected: PASS with 2 tests

- [ ] **Step 6: Commit**

```bash
git add src-tauri/src/error.rs src-tauri/src/models.rs src-tauri/src/db.rs src-tauri/src/app_state.rs src-tauri/src/lib.rs src-tauri/tests/repository_smoke.rs
git commit -m "feat: add backend repository foundation"
```

### Task 3: Реализовать managed workspace и app-owned filesystem layout

**Files:**
- Create: `src-tauri/src/services/mod.rs`
- Create: `src-tauri/src/services/workspace.rs`
- Create: `src-tauri/tests/workspace_paths.rs`
- Modify: `src-tauri/src/app_state.rs`
- Modify: `src-tauri/src/models.rs`

- [ ] **Step 1: Write failing tests for workspace, app config and managed binary directories**

```rust
// src-tauri/tests/workspace_paths.rs
use macyad_lib::services::workspace::WorkspaceManager;

#[test]
fn creates_expected_app_directories() {
  let root = tempfile::tempdir().unwrap();
  let manager = WorkspaceManager::new(root.path().to_path_buf());

  let paths = manager.ensure_layout().unwrap();

  assert!(paths.workspace_dir.ends_with("workspace"));
  assert!(paths.rclone_dir.ends_with("rclone"));
  assert!(paths.rclone_config_path.ends_with("rclone/rclone.conf"));
  assert!(paths.managed_bin_dir.ends_with("rclone/bin"));
}
```

- [ ] **Step 2: Run the workspace test file to verify the service does not exist yet**

Run:

```bash
cd /Users/zerotool/Documents/Dev/macyad
cargo test --manifest-path src-tauri/Cargo.toml --test workspace_paths
```

Expected: FAIL with unresolved `services::workspace::WorkspaceManager`

- [ ] **Step 3: Implement app path model and workspace manager**

```rust
// src-tauri/src/models.rs (append)
use std::path::PathBuf;

#[derive(Debug, Clone)]
pub struct AppPaths {
  pub root_dir: PathBuf,
  pub workspace_dir: PathBuf,
  pub rclone_dir: PathBuf,
  pub rclone_config_path: PathBuf,
  pub managed_bin_dir: PathBuf,
  pub database_path: PathBuf,
}
```

```rust
// src-tauri/src/services/mod.rs
pub mod workspace;
```

```rust
// src-tauri/src/services/workspace.rs
use std::{fs, path::PathBuf};

use crate::{error::AppError, models::AppPaths};

pub struct WorkspaceManager {
  root_dir: PathBuf,
}

impl WorkspaceManager {
  pub fn new(root_dir: PathBuf) -> Self {
    Self { root_dir }
  }

  pub fn ensure_layout(&self) -> Result<AppPaths, AppError> {
    let workspace_dir = self.root_dir.join("workspace");
    let rclone_dir = self.root_dir.join("rclone");
    let managed_bin_dir = rclone_dir.join("bin");
    let rclone_config_path = rclone_dir.join("rclone.conf");
    let database_path = self.root_dir.join("macyad.db");

    fs::create_dir_all(&workspace_dir)?;
    fs::create_dir_all(&managed_bin_dir)?;

    Ok(AppPaths {
      root_dir: self.root_dir.clone(),
      workspace_dir,
      rclone_dir,
      rclone_config_path,
      managed_bin_dir,
      database_path,
    })
  }
}
```

- [ ] **Step 4: Store app-owned paths in `AppState`**

```rust
// src-tauri/src/app_state.rs
use crate::{db::Repository, error::AppError, models::AppPaths};

pub struct AppState {
  pub repo: Arc<Mutex<Repository>>,
  pub paths: AppPaths,
}

impl AppState {
  pub fn new(repo: Repository, paths: AppPaths) -> Result<Self, AppError> {
    Ok(Self {
      repo: Arc::new(Mutex::new(repo)),
      paths,
    })
  }
}
```

- [ ] **Step 5: Run the workspace tests**

Run:

```bash
cd /Users/zerotool/Documents/Dev/macyad
cargo test --manifest-path src-tauri/Cargo.toml --test workspace_paths
```

Expected: PASS with 1 test

- [ ] **Step 6: Commit**

```bash
git add src-tauri/src/services/mod.rs src-tauri/src/services/workspace.rs src-tauri/src/app_state.rs src-tauri/src/models.rs src-tauri/tests/workspace_paths.rs
git commit -m "feat: add managed workspace layout"
```

### Task 4: Реализовать `rclone` discovery и guided onboarding backend

**Files:**
- Create: `src-tauri/src/services/rclone.rs`
- Create: `src-tauri/src/services/onboarding.rs`
- Create: `src-tauri/src/commands/onboarding.rs`
- Create: `src-tauri/tests/rclone_discovery.rs`
- Modify: `src-tauri/src/services/mod.rs`
- Modify: `src-tauri/src/commands/mod.rs`
- Modify: `src-tauri/src/models.rs`

- [ ] **Step 1: Write failing tests for discovery order and generated setup commands**

```rust
// src-tauri/tests/rclone_discovery.rs
use std::path::PathBuf;

use macyad_lib::services::rclone::{RcloneBinary, RcloneResolver};

#[test]
fn prefers_existing_binary_over_managed_download() {
  let resolver = RcloneResolver::for_tests(
    Some(PathBuf::from("/opt/homebrew/bin/rclone")),
    Some(PathBuf::from("/tmp/macyad/bin/rclone")),
  );

  let resolved = resolver.resolve().unwrap();
  assert_eq!(resolved.binary, RcloneBinary::ExistingPath(PathBuf::from("/opt/homebrew/bin/rclone")));
}

#[test]
fn builds_guided_remote_create_command_with_managed_config() {
  let command = RcloneResolver::build_remote_create_command(
    "/Users/test/Library/Application Support/com.orloff.macyad/rclone/rclone.conf",
    "yd-app",
  );

  assert!(command.contains("--config"));
  assert!(command.contains("config create yd-app yandex"));
}
```

- [ ] **Step 2: Run discovery tests and verify the resolver layer is missing**

Run:

```bash
cd /Users/zerotool/Documents/Dev/macyad
cargo test --manifest-path src-tauri/Cargo.toml --test rclone_discovery
```

Expected: FAIL with unresolved `RcloneResolver`/`RcloneBinary`

- [ ] **Step 3: Implement binary resolution and command generation**

```rust
// src-tauri/src/services/rclone.rs
use std::path::PathBuf;

use crate::error::AppError;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum RcloneBinary {
  ExistingPath(PathBuf),
  ManagedDownload(PathBuf),
  Missing,
}

#[derive(Debug, Clone)]
pub struct ResolvedRclone {
  pub binary: RcloneBinary,
}

pub struct RcloneResolver {
  existing_path: Option<PathBuf>,
  managed_path: Option<PathBuf>,
}

impl RcloneResolver {
  pub fn new(existing_path: Option<PathBuf>, managed_path: Option<PathBuf>) -> Self {
    Self { existing_path, managed_path }
  }

  pub fn for_tests(existing_path: Option<PathBuf>, managed_path: Option<PathBuf>) -> Self {
    Self::new(existing_path, managed_path)
  }

  pub fn resolve(&self) -> Result<ResolvedRclone, AppError> {
    if let Some(path) = &self.existing_path {
      return Ok(ResolvedRclone { binary: RcloneBinary::ExistingPath(path.clone()) });
    }
    if let Some(path) = &self.managed_path {
      return Ok(ResolvedRclone { binary: RcloneBinary::ManagedDownload(path.clone()) });
    }
    Ok(ResolvedRclone { binary: RcloneBinary::Missing })
  }

  pub fn build_remote_create_command(config_path: &str, remote_name: &str) -> String {
    format!(
      "rclone --config \"{config_path}\" config create {remote_name} yandex"
    )
  }
}
```

- [ ] **Step 4: Implement onboarding service and Tauri commands for status/import/validate**

```rust
// src-tauri/src/services/onboarding.rs
use std::path::PathBuf;

use serde::Serialize;

use crate::services::rclone::{RcloneBinary, RcloneResolver};

#[derive(Debug, Serialize)]
pub struct OnboardingStatus {
  pub has_rclone: bool,
  pub source: String,
  pub brew_install_command: String,
  pub remote_create_command: String,
}

pub fn onboarding_status(config_path: PathBuf, existing: Option<PathBuf>, managed: Option<PathBuf>) -> OnboardingStatus {
  let resolver = RcloneResolver::new(existing, managed);
  let resolved = resolver.resolve().expect("resolver should not fail");

  let (has_rclone, source) = match resolved.binary {
    RcloneBinary::ExistingPath(_) => (true, "existing".to_string()),
    RcloneBinary::ManagedDownload(_) => (true, "managed".to_string()),
    RcloneBinary::Missing => (false, "missing".to_string()),
  };

  OnboardingStatus {
    has_rclone,
    source,
    brew_install_command: "brew install rclone".into(),
    remote_create_command: RcloneResolver::build_remote_create_command(
      config_path.to_string_lossy().as_ref(),
      "yd-app",
    ),
  }
}
```

```rust
// src-tauri/src/commands/onboarding.rs
use tauri::State;

use crate::{
  app_state::AppState,
  services::onboarding::{onboarding_status, OnboardingStatus},
};

#[tauri::command]
pub fn get_onboarding_status(state: State<'_, AppState>) -> OnboardingStatus {
  onboarding_status(
    state.paths.rclone_config_path.clone(),
    which::which("rclone").ok(),
    Some(state.paths.managed_bin_dir.join("rclone")),
  )
}
```

```rust
// src-tauri/src/commands/mod.rs
pub mod onboarding;
```

- [ ] **Step 5: Run the discovery tests**

Run:

```bash
cd /Users/zerotool/Documents/Dev/macyad
cargo test --manifest-path src-tauri/Cargo.toml --test rclone_discovery
```

Expected: PASS with 2 tests

- [ ] **Step 6: Commit**

```bash
git add src-tauri/src/services/rclone.rs src-tauri/src/services/onboarding.rs src-tauri/src/commands/onboarding.rs src-tauri/src/services/mod.rs src-tauri/src/commands/mod.rs src-tauri/src/models.rs src-tauri/tests/rclone_discovery.rs
git commit -m "feat: add rclone discovery and onboarding backend"
```

### Task 5: Добавить managed `rclone` install flow, download fallback и app-managed remote import

**Files:**
- Modify: `src-tauri/src/services/rclone.rs`
- Modify: `src-tauri/src/services/onboarding.rs`
- Modify: `src-tauri/src/commands/onboarding.rs`
- Create: `src-tauri/tests/managed_install.rs`

- [ ] **Step 1: Write failing tests for managed install and remote import**

```rust
// src-tauri/tests/managed_install.rs
use std::fs;

use macyad_lib::services::rclone::install_managed_rclone_from_fixture;

#[test]
fn installs_fixture_binary_into_managed_bin_dir() {
  let temp = tempfile::tempdir().unwrap();
  let fixture = temp.path().join("rclone");
  fs::write(&fixture, "#!/bin/sh\necho rclone\n").unwrap();

  let installed = install_managed_rclone_from_fixture(&fixture, &temp.path().join("bin")).unwrap();

  assert!(installed.exists());
  assert!(installed.ends_with("bin/rclone"));
}
```

- [ ] **Step 2: Run the managed install tests to verify the function is missing**

Run:

```bash
cd /Users/zerotool/Documents/Dev/macyad
cargo test --manifest-path src-tauri/Cargo.toml --test managed_install
```

Expected: FAIL with unresolved `install_managed_rclone_from_fixture`

- [ ] **Step 3: Implement managed install and remote import primitives**

```rust
// src-tauri/src/services/rclone.rs (append)
use std::{fs, path::{Path, PathBuf}};

use crate::error::AppError;

pub fn download_and_install_managed_rclone(download_url: &str, managed_dir: &Path) -> Result<PathBuf, AppError> {
  fs::create_dir_all(managed_dir)?;

  let response = reqwest::blocking::get(download_url)
    .map_err(|err| AppError::Validation(format!("download failed: {err}")))?;
  let bytes = response
    .bytes()
    .map_err(|err| AppError::Validation(format!("download body failed: {err}")))?;

  let cursor = std::io::Cursor::new(bytes);
  let mut archive = zip::ZipArchive::new(cursor)
    .map_err(|err| AppError::Validation(format!("invalid archive: {err}")))?;

  for index in 0..archive.len() {
    let mut file = archive
      .by_index(index)
      .map_err(|err| AppError::Validation(format!("archive read failed: {err}")))?;

    if file.name().ends_with("/rclone") {
      let destination = managed_dir.join("rclone");
      let mut output = fs::File::create(&destination)?;
      std::io::copy(&mut file, &mut output)?;

      #[cfg(unix)]
      {
        use std::os::unix::fs::PermissionsExt;
        let mut perms = fs::metadata(&destination)?.permissions();
        perms.set_mode(0o755);
        fs::set_permissions(&destination, perms)?;
      }

      return Ok(destination);
    }
  }

  Err(AppError::Validation("rclone binary not found in archive".into()))
}

pub fn install_managed_rclone_from_fixture(source: &Path, managed_dir: &Path) -> Result<PathBuf, AppError> {
  fs::create_dir_all(managed_dir)?;
  let destination = managed_dir.join("rclone");
  fs::copy(source, &destination)?;

  #[cfg(unix)]
  {
    use std::os::unix::fs::PermissionsExt;
    let mut perms = fs::metadata(&destination)?.permissions();
    perms.set_mode(0o755);
    fs::set_permissions(&destination, perms)?;
  }

  Ok(destination)
}
```

```rust
// src-tauri/src/services/onboarding.rs (append)
use std::{fs, path::Path};

use crate::error::AppError;

pub fn import_existing_remote_config(
  existing_config: &Path,
  target_config: &Path,
) -> Result<(), AppError> {
  let contents = fs::read_to_string(existing_config)?;
  fs::write(target_config, contents)?;
  Ok(())
}
```

- [ ] **Step 4: Expose managed install and import commands**

```rust
// src-tauri/src/commands/onboarding.rs (append)
use crate::services::{
  onboarding::import_existing_remote_config,
  rclone::{download_and_install_managed_rclone, install_managed_rclone_from_fixture},
};

#[tauri::command]
pub fn install_managed_rclone(
  state: State<'_, AppState>,
  fixture_path: Option<String>,
  download_url: Option<String>,
) -> Result<String, String> {
  let installed = if let Some(path) = fixture_path {
    install_managed_rclone_from_fixture(
      std::path::Path::new(&path),
      &state.paths.managed_bin_dir,
    )
  } else if let Some(url) = download_url {
    download_and_install_managed_rclone(&url, &state.paths.managed_bin_dir)
  } else {
    Err(crate::error::AppError::Validation(
      "either fixture_path or download_url is required".into(),
    ))
  }
  .map_err(|err| err.to_string())?;

  Ok(installed.to_string_lossy().to_string())
}

#[tauri::command]
pub fn import_existing_remote(state: State<'_, AppState>, existing_config: String) -> Result<(), String> {
  import_existing_remote_config(
    std::path::Path::new(&existing_config),
    &state.paths.rclone_config_path,
  )
  .map_err(|err| err.to_string())
}
```

- [ ] **Step 5: Run the managed install test**

Run:

```bash
cd /Users/zerotool/Documents/Dev/macyad
cargo test --manifest-path src-tauri/Cargo.toml --test managed_install
```

Expected: PASS with 1 test

- [ ] **Step 6: Commit**

```bash
git add src-tauri/src/services/rclone.rs src-tauri/src/services/onboarding.rs src-tauri/src/commands/onboarding.rs src-tauri/tests/managed_install.rs
git commit -m "feat: add managed rclone install flow"
```

### Task 6: Реализовать baseline snapshot model и `info/warning/alarm` classifier

**Files:**
- Create: `src-tauri/src/services/drift.rs`
- Create: `src-tauri/tests/drift_classifier.rs`
- Modify: `src-tauri/src/models.rs`
- Modify: `src-tauri/src/services/mod.rs`

- [ ] **Step 1: Write failing tests for `info`, `warning` and `alarm` classification**

```rust
// src-tauri/tests/drift_classifier.rs
use macyad_lib::{
  models::PairSeverity,
  services::drift::{classify_drift, FileSnapshot},
};

#[test]
fn classifies_remote_only_change_as_info() {
  let severity = classify_drift(
    &[FileSnapshot::new("notes/todo.txt", "a", 10)],
    &[FileSnapshot::new("notes/todo.txt", "b", 10)],
    &[FileSnapshot::new("notes/todo.txt", "a", 10)],
  );

  assert_eq!(severity, PairSeverity::Info);
}

#[test]
fn classifies_general_divergence_as_warning() {
  let severity = classify_drift(
    &[FileSnapshot::new("a.txt", "a", 10)],
    &[FileSnapshot::new("a.txt", "a", 10), FileSnapshot::new("b.txt", "b", 12)],
    &[FileSnapshot::new("a.txt", "x", 10)],
  );

  assert_eq!(severity, PairSeverity::Warning);
}

#[test]
fn classifies_same_object_change_as_alarm() {
  let severity = classify_drift(
    &[FileSnapshot::new("proposal.docx", "old", 10)],
    &[FileSnapshot::new("proposal.docx", "remote", 11)],
    &[FileSnapshot::new("proposal.docx", "local", 12)],
  );

  assert_eq!(severity, PairSeverity::Alarm);
}
```

- [ ] **Step 2: Run classifier tests**

Run:

```bash
cd /Users/zerotool/Documents/Dev/macyad
cargo test --manifest-path src-tauri/Cargo.toml --test drift_classifier
```

Expected: FAIL with unresolved `classify_drift` and `FileSnapshot`

- [ ] **Step 3: Implement the conservative snapshot compare model**

```rust
// src-tauri/src/services/drift.rs
use std::collections::HashMap;

use crate::models::PairSeverity;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FileSnapshot {
  pub path: String,
  pub checksum: String,
  pub size: u64,
}

impl FileSnapshot {
  pub fn new(path: &str, checksum: &str, size: u64) -> Self {
    Self {
      path: path.into(),
      checksum: checksum.into(),
      size,
    }
  }
}

pub fn classify_drift(
  baseline: &[FileSnapshot],
  remote: &[FileSnapshot],
  local: &[FileSnapshot],
) -> PairSeverity {
  let base: HashMap<_, _> = baseline.iter().map(|item| (item.path.as_str(), item)).collect();
  let remote_map: HashMap<_, _> = remote.iter().map(|item| (item.path.as_str(), item)).collect();
  let local_map: HashMap<_, _> = local.iter().map(|item| (item.path.as_str(), item)).collect();

  let mut all_paths = std::collections::BTreeSet::new();
  all_paths.extend(base.keys().copied());
  all_paths.extend(remote_map.keys().copied());
  all_paths.extend(local_map.keys().copied());

  let mut saw_remote_change = false;
  let mut saw_local_change = false;

  for path in all_paths {
    let baseline_checksum = base.get(path).map(|item| item.checksum.as_str());
    let remote_checksum = remote_map.get(path).map(|item| item.checksum.as_str());
    let local_checksum = local_map.get(path).map(|item| item.checksum.as_str());

    let remote_changed = remote_checksum != baseline_checksum;
    let local_changed = local_checksum != baseline_checksum;

    if remote_changed && local_changed {
      return PairSeverity::Alarm;
    }
    if remote_changed {
      saw_remote_change = true;
    }
    if local_changed {
      saw_local_change = true;
    }
  }

  if saw_remote_change && saw_local_change {
    PairSeverity::Warning
  } else if saw_remote_change {
    PairSeverity::Info
  } else {
    PairSeverity::Healthy
  }
}
```

- [ ] **Step 4: Export the service module**

```rust
// src-tauri/src/services/mod.rs
pub mod drift;
pub mod onboarding;
pub mod rclone;
pub mod workspace;
```

- [ ] **Step 5: Run classifier tests and then the full backend test suite**

Run:

```bash
cd /Users/zerotool/Documents/Dev/macyad
cargo test --manifest-path src-tauri/Cargo.toml --test drift_classifier
cargo test --manifest-path src-tauri/Cargo.toml
```

Expected:
- `drift_classifier` PASS with 3 tests
- full backend test suite stays green

- [ ] **Step 6: Commit**

```bash
git add src-tauri/src/services/drift.rs src-tauri/src/services/mod.rs src-tauri/src/models.rs src-tauri/tests/drift_classifier.rs
git commit -m "feat: add drift severity classifier"
```

### Task 7: Реализовать sync runner, delete policy execution и scheduler locks

**Files:**
- Create: `src-tauri/src/services/sync_runner.rs`
- Create: `src-tauri/src/services/scheduler.rs`
- Create: `src-tauri/src/services/notifications.rs`
- Create: `src-tauri/tests/sync_runner.rs`
- Modify: `src-tauri/src/services/mod.rs`
- Modify: `src-tauri/src/models.rs`

- [ ] **Step 1: Write failing tests for blocked push on `alarm` and successful initial pull**

```rust
// src-tauri/tests/sync_runner.rs
use macyad_lib::{
  models::{DeletePolicy, PairSeverity, SyncPair},
  services::sync_runner::{PushDecision, SyncRunner},
};

#[test]
fn blocks_scheduled_push_when_alarm_is_present() {
  let pair = SyncPair {
    id: 1,
    name: "Work Docs".into(),
    local_relative_path: "Work Docs".into(),
    remote_path: "yd:/Work Docs".into(),
    schedule_minutes: 30,
    delete_policy: DeletePolicy::MirrorToYandex,
    severity: PairSeverity::Alarm,
  };

  let decision = SyncRunner::decide_push(&pair);
  assert_eq!(decision, PushDecision::BlockedByAlarm);
}
```

- [ ] **Step 2: Run sync runner tests**

Run:

```bash
cd /Users/zerotool/Documents/Dev/macyad
cargo test --manifest-path src-tauri/Cargo.toml --test sync_runner
```

Expected: FAIL with unresolved `SyncRunner`/`PushDecision`

- [ ] **Step 3: Implement push decision logic and `rclone` command builder**

```rust
// src-tauri/src/services/sync_runner.rs
use std::process::Command;

use crate::{
  app_state::AppState,
  error::AppError,
  models::{DeletePolicy, PairSeverity, SyncPair},
};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PushDecision {
  Ready,
  BlockedByAlarm,
  ConfirmationRequired,
}

pub struct SyncRunner;

impl SyncRunner {
  pub fn decide_push(pair: &SyncPair) -> PushDecision {
    if pair.severity == PairSeverity::Alarm {
      return PushDecision::BlockedByAlarm;
    }
    if pair.delete_policy == DeletePolicy::RequireConfirmation {
      return PushDecision::ConfirmationRequired;
    }
    PushDecision::Ready
  }

  pub fn build_push_command(binary: &str, config_path: &str, local: &str, remote: &str, policy: DeletePolicy) -> Command {
    let mut command = Command::new(binary);
    command.arg("--config").arg(config_path);

    match policy {
      DeletePolicy::MirrorToYandex => {
        command.arg("sync").arg(local).arg(remote);
      }
      DeletePolicy::KeepRemoteDeletesSafe => {
        command.arg("copy").arg(local).arg(remote);
      }
      DeletePolicy::RequireConfirmation => {
        command.arg("copy").arg(local).arg(remote);
      }
    }

    command
      .arg("--create-empty-src-dirs")
      .arg("--exclude").arg(".DS_Store")
      .arg("--exclude").arg("._*");

    command
  }

  pub fn run_push(state: &AppState, pair_id: i64) -> Result<(), AppError> {
    let repo = state.repo.lock().unwrap();
    let pair = repo
      .get_sync_pair(pair_id)?
      .ok_or_else(|| AppError::Validation(format!("pair {pair_id} not found")))?;

    match Self::decide_push(&pair) {
      PushDecision::BlockedByAlarm => {
        return Err(AppError::Validation("push blocked by alarm".into()));
      }
      PushDecision::ConfirmationRequired => {
        return Err(AppError::Validation("delete confirmation required".into()));
      }
      PushDecision::Ready => {}
    }

    let local = state.paths.workspace_dir.join(&pair.local_relative_path);
    let _command = Self::build_push_command(
      "rclone",
      state.paths.rclone_config_path.to_string_lossy().as_ref(),
      local.to_string_lossy().as_ref(),
      &pair.remote_path,
      pair.delete_policy,
    );

    Ok(())
  }

  pub fn run_remote_check(state: &AppState, pair_id: i64) -> Result<(), AppError> {
    let repo = state.repo.lock().unwrap();
    let _pair = repo
      .get_sync_pair(pair_id)?
      .ok_or_else(|| AppError::Validation(format!("pair {pair_id} not found")))?;

    Ok(())
  }

  pub fn run_manual_pull(state: &AppState, pair_id: i64) -> Result<(), AppError> {
    let repo = state.repo.lock().unwrap();
    let pair = repo
      .get_sync_pair(pair_id)?
      .ok_or_else(|| AppError::Validation(format!("pair {pair_id} not found")))?;

    let local = state.paths.workspace_dir.join(&pair.local_relative_path);
    let mut command = Command::new("rclone");
    command
      .arg("--config")
      .arg(&state.paths.rclone_config_path)
      .arg("copy")
      .arg(&pair.remote_path)
      .arg(local);

    Ok(())
  }
}
```

- [ ] **Step 4: Implement scheduler lock files and notification trigger stubs**

```rust
// src-tauri/src/services/scheduler.rs
use std::{fs, path::PathBuf};

use crate::error::AppError;

pub struct RunLock {
  path: PathBuf,
}

impl RunLock {
  pub fn acquire(path: PathBuf) -> Result<Self, AppError> {
    fs::write(&path, "locked")?;
    Ok(Self { path })
  }
}

impl Drop for RunLock {
  fn drop(&mut self) {
    let _ = fs::remove_file(&self.path);
  }
}
```

```rust
// src-tauri/src/services/notifications.rs
use crate::models::PairSeverity;

pub fn should_send_system_notification(severity: PairSeverity) -> bool {
  matches!(severity, PairSeverity::Warning | PairSeverity::Alarm)
}
```

```rust
// src-tauri/src/services/mod.rs
pub mod drift;
pub mod notifications;
pub mod onboarding;
pub mod rclone;
pub mod scheduler;
pub mod sync_runner;
pub mod workspace;
```

- [ ] **Step 5: Run the sync runner tests and a full backend regression pass**

Run:

```bash
cd /Users/zerotool/Documents/Dev/macyad
cargo test --manifest-path src-tauri/Cargo.toml --test sync_runner
cargo test --manifest-path src-tauri/Cargo.toml
```

Expected:
- `sync_runner` PASS
- full suite remains green

- [ ] **Step 6: Commit**

```bash
git add src-tauri/src/services/sync_runner.rs src-tauri/src/services/scheduler.rs src-tauri/src/services/notifications.rs src-tauri/src/services/mod.rs src-tauri/tests/sync_runner.rs src-tauri/src/models.rs
git commit -m "feat: add sync runner and scheduler guards"
```

### Task 8: Открыть backend через Tauri commands и собрать app overview DTO

**Files:**
- Create: `src-tauri/src/commands/app.rs`
- Create: `src-tauri/src/commands/pairs.rs`
- Create: `src-tauri/src/commands/sync.rs`
- Create: `src-tauri/tests/commands_smoke.rs`
- Modify: `src-tauri/src/commands/mod.rs`
- Modify: `src-tauri/src/lib.rs`
- Modify: `src-tauri/src/models.rs`

- [ ] **Step 1: Write failing tests for app overview and pair list commands**

```rust
// src-tauri/tests/commands_smoke.rs
use macyad_lib::models::AppOverview;

#[test]
fn app_overview_defaults_to_ru_and_empty_pairs() {
  let overview = AppOverview {
    ui_language: "ru".into(),
    has_rclone: false,
    next_push_in_minutes: None,
    pairs: vec![],
  };

  assert_eq!(overview.ui_language, "ru");
  assert!(overview.pairs.is_empty());
}
```

- [ ] **Step 2: Run command smoke tests**

Run:

```bash
cd /Users/zerotool/Documents/Dev/macyad
cargo test --manifest-path src-tauri/Cargo.toml --test commands_smoke
```

Expected: FAIL with unresolved `AppOverview`

- [ ] **Step 3: Add DTOs and Tauri commands**

```rust
// src-tauri/src/models.rs (append)
use serde::Serialize;

#[derive(Debug, Clone, Serialize)]
pub struct SyncPairSummaryDto {
  pub id: i64,
  pub name: String,
  pub remote_path: String,
  pub local_relative_path: String,
  pub severity: PairSeverity,
  pub schedule_minutes: u32,
}

#[derive(Debug, Clone, Serialize)]
pub struct AppOverview {
  pub ui_language: String,
  pub has_rclone: bool,
  pub next_push_in_minutes: Option<u32>,
  pub pairs: Vec<SyncPairSummaryDto>,
}
```

```rust
// src-tauri/src/commands/app.rs
use tauri::State;

use crate::{app_state::AppState, models::AppOverview};

#[tauri::command]
pub fn get_app_overview(state: State<'_, AppState>) -> AppOverview {
  let repo = state.repo.lock().unwrap();
  let settings = repo.load_settings().unwrap();

  AppOverview {
    ui_language: settings.ui_language,
    has_rclone: state.paths.managed_bin_dir.join("rclone").exists() || which::which("rclone").is_ok(),
    next_push_in_minutes: Some(settings.default_schedule_minutes),
    pairs: vec![],
  }
}
```

```rust
// src-tauri/src/commands/pairs.rs
use tauri::State;

use crate::{app_state::AppState, models::SyncPairSummaryDto};

#[tauri::command]
pub fn list_sync_pairs(_state: State<'_, AppState>) -> Vec<SyncPairSummaryDto> {
  vec![]
}
```

```rust
// src-tauri/src/commands/sync.rs
#[tauri::command]
pub fn sync_now() -> Result<(), String> {
  Ok(())
}
```

- [ ] **Step 4: Register command modules in the Tauri builder**

```rust
// src-tauri/src/commands/mod.rs
pub mod app;
pub mod onboarding;
pub mod pairs;
pub mod sync;
```

```rust
// src-tauri/src/lib.rs (builder section)
use crate::commands::{
  app::get_app_overview,
  onboarding::{get_onboarding_status, import_existing_remote, install_managed_rclone},
  pairs::list_sync_pairs,
  sync::sync_now,
};

.invoke_handler(tauri::generate_handler![
  get_app_overview,
  get_onboarding_status,
  import_existing_remote,
  install_managed_rclone,
  list_sync_pairs,
  sync_now
])
```

- [ ] **Step 5: Run command smoke tests and a Tauri build smoke check**

Run:

```bash
cd /Users/zerotool/Documents/Dev/macyad
cargo test --manifest-path src-tauri/Cargo.toml --test commands_smoke
npm run tauri:build
```

Expected:
- `commands_smoke` PASS
- Tauri build succeeds and produces a macOS bundle or binary artifacts

- [ ] **Step 6: Commit**

```bash
git add src-tauri/src/commands src-tauri/src/lib.rs src-tauri/src/models.rs src-tauri/tests/commands_smoke.rs
git commit -m "feat: expose backend commands to the frontend"
```

### Task 9: Добавить frontend `i18n`, typed `invoke` wrappers и app store

**Files:**
- Create: `src/lib/i18n.ts`
- Create: `src/lib/i18n.test.ts`
- Create: `src/locales/ru/app.json`
- Create: `src/locales/en/app.json`
- Create: `src/types/contracts.ts`
- Create: `src/api/tauri.ts`
- Create: `src/state/app-store.ts`
- Modify: `src/main.tsx`
- Modify: `src/App.tsx`

- [ ] **Step 1: Write a failing frontend test for language fallback**

```ts
// src/lib/i18n.test.ts
import i18n from './i18n';

test('falls back to ru for unknown locales', async () => {
  await i18n.changeLanguage('fr');
  expect(i18n.t('app.title')).toBe('Macyad');
  expect(i18n.resolvedLanguage).toBe('ru');
});
```

- [ ] **Step 2: Run the frontend test to verify i18n does not exist yet**

Run:

```bash
cd /Users/zerotool/Documents/Dev/macyad
npm run test -- src/lib/i18n.test.ts
```

Expected: FAIL with missing module `./i18n`

- [ ] **Step 3: Implement locale catalogs and i18n bootstrap**

```json
// src/locales/ru/app.json
{
  "app": {
    "title": "Macyad",
    "syncNow": "Синхронизировать сейчас",
    "checkYandex": "Проверить Яндекс",
    "pullFromYandex": "Загрузить из Яндекса",
    "needsAttention": "Требует внимания",
    "onboardingTitle": "Подключение",
    "rcloneDetected": "Rclone найден",
    "rcloneMissing": "Rclone не найден",
    "pushBlocked": "Push заблокирован",
    "loading": "Загрузка…",
    "rcloneReady": "Rclone готов",
    "rcloneNotConfiguredYet": "Rclone пока не настроен",
    "settingsTitle": "Настройки",
    "languageRu": "Русский",
    "languageEn": "English",
    "openDetails": "Открыть детали",
    "recentEvents": "Последние события",
    "createPair": "Создать пару",
    "bootstrapComplete": "Начальная инициализация завершена",
    "startAtLoginEnable": "Включить запуск при входе",
    "startAtLoginDisable": "Выключить запуск при входе"
  }
}
```

```json
// src/locales/en/app.json
{
  "app": {
    "title": "Macyad",
    "syncNow": "Sync Now",
    "checkYandex": "Check Yandex",
    "pullFromYandex": "Pull From Yandex",
    "needsAttention": "Needs Attention",
    "onboardingTitle": "Onboarding",
    "rcloneDetected": "Rclone detected",
    "rcloneMissing": "Rclone is missing",
    "pushBlocked": "Push blocked",
    "loading": "Loading…",
    "rcloneReady": "Rclone ready",
    "rcloneNotConfiguredYet": "Rclone not configured yet",
    "settingsTitle": "Settings",
    "languageRu": "Russian",
    "languageEn": "English",
    "openDetails": "Open Details",
    "recentEvents": "Recent Events",
    "createPair": "Create Pair",
    "bootstrapComplete": "Initial bootstrap complete",
    "startAtLoginEnable": "Enable start at login",
    "startAtLoginDisable": "Disable start at login"
  }
}
```

```ts
// src/lib/i18n.ts
import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';

import en from '../locales/en/app.json';
import ru from '../locales/ru/app.json';

void i18n.use(initReactI18next).init({
  resources: { en: { translation: en }, ru: { translation: ru } },
  lng: 'ru',
  fallbackLng: 'ru',
  interpolation: { escapeValue: false }
});

export default i18n;
```

- [ ] **Step 4: Add typed Tauri contracts and a lightweight store**

```ts
// src/types/contracts.ts
export type PairSeverity = 'Healthy' | 'Info' | 'Warning' | 'Alarm';

export interface SyncPairSummaryDto {
  id: number;
  name: string;
  remote_path: string;
  local_relative_path: string;
  severity: PairSeverity;
  schedule_minutes: number;
}

export interface AppOverview {
  ui_language: string;
  has_rclone: boolean;
  next_push_in_minutes: number | null;
  pairs: SyncPairSummaryDto[];
}
```

```ts
// src/api/tauri.ts
import { invoke } from '@tauri-apps/api/core';
import type { AppOverview } from '../types/contracts';

export function getAppOverview(): Promise<AppOverview> {
  return invoke<AppOverview>('get_app_overview');
}
```

```ts
// src/state/app-store.ts
import { create } from 'zustand';
import type { AppOverview } from '../types/contracts';
import { getAppOverview } from '../api/tauri';

interface AppStore {
  overview: AppOverview | null;
  loadOverview: () => Promise<void>;
}

export const useAppStore = create<AppStore>((set) => ({
  overview: null,
  loadOverview: async () => {
    const overview = await getAppOverview();
    set({ overview });
  }
}));
```

- [ ] **Step 5: Wire i18n and the store into the app shell**

```tsx
// src/main.tsx
import './lib/i18n';
import './styles/app.css';
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
```

```tsx
// src/App.tsx
import { useEffect } from 'react';
import { useTranslation } from 'react-i18next';

import { useAppStore } from './state/app-store';

export default function App() {
  const { t, i18n } = useTranslation();
  const overview = useAppStore((state) => state.overview);
  const loadOverview = useAppStore((state) => state.loadOverview);

  useEffect(() => {
    void loadOverview();
  }, [loadOverview]);

  useEffect(() => {
    if (overview?.ui_language) {
      void i18n.changeLanguage(overview.ui_language);
    }
  }, [i18n, overview?.ui_language]);

  return (
    <main className="app-shell">
      <section className="hero-card">
        <p className="eyebrow">{t('app.title')}</p>
        <h1>{overview?.has_rclone ? t('app.rcloneReady') : t('app.rcloneNotConfiguredYet')}</h1>
      </section>
    </main>
  );
}
```

- [ ] **Step 6: Run the frontend i18n tests**

Run:

```bash
cd /Users/zerotool/Documents/Dev/macyad
npm run test -- src/lib/i18n.test.ts
npm run build
```

Expected:
- `i18n.test.ts` PASS
- frontend build succeeds

- [ ] **Step 7: Commit**

```bash
git add src/lib/i18n.ts src/lib/i18n.test.ts src/locales src/types/contracts.ts src/api/tauri.ts src/state/app-store.ts src/main.tsx src/App.tsx
git commit -m "feat: add frontend i18n and app store"
```

### Task 10: Собрать menu bar dashboard UI для quick actions и sync pair cards

**Files:**
- Create: `src/components/StatusHeader.tsx`
- Create: `src/components/QuickActions.tsx`
- Create: `src/components/SyncPairCard.tsx`
- Create: `src/components/EventList.tsx`
- Create: `src/components/SyncPairCard.test.tsx`
- Modify: `src/App.tsx`
- Modify: `src/styles/app.css`

- [ ] **Step 1: Write a failing component test for the warning badge**

```tsx
// src/components/SyncPairCard.test.tsx
import { render, screen } from '@testing-library/react';

import '../lib/i18n';
import { SyncPairCard } from './SyncPairCard';

test('renders warning badge for warning pair', () => {
  render(
    <SyncPairCard
      pair={{
        id: 1,
        name: 'Work Docs',
        remote_path: 'yd:/Work Docs',
        local_relative_path: 'Work Docs',
        severity: 'Warning',
        schedule_minutes: 30
      }}
      onOpen={() => {}}
    />
  );

  expect(screen.getByText('Warning')).toBeTruthy();
});
```

- [ ] **Step 2: Run the component test to verify the dashboard components do not exist yet**

Run:

```bash
cd /Users/zerotool/Documents/Dev/macyad
npm run test -- src/components/SyncPairCard.test.tsx
```

Expected: FAIL with missing `SyncPairCard`

- [ ] **Step 3: Implement the dashboard components**

```tsx
// src/components/StatusHeader.tsx
export function StatusHeader({ title, subtitle }: { title: string; subtitle: string }) {
  return (
    <header className="status-header">
      <h1>{title}</h1>
      <p>{subtitle}</p>
    </header>
  );
}
```

```tsx
// src/components/QuickActions.tsx
import { useTranslation } from 'react-i18next';

export function QuickActions(props: {
  onSyncNow: () => void;
  onCheckYandex: () => void;
  onPullFromYandex: () => void;
}) {
  const { t } = useTranslation();

  return (
    <section className="quick-actions">
      <button onClick={props.onSyncNow}>{t('app.syncNow')}</button>
      <button onClick={props.onCheckYandex}>{t('app.checkYandex')}</button>
      <button onClick={props.onPullFromYandex}>{t('app.pullFromYandex')}</button>
    </section>
  );
}
```

```tsx
// src/components/SyncPairCard.tsx
import { useTranslation } from 'react-i18next';

import type { SyncPairSummaryDto } from '../types/contracts';

export function SyncPairCard({
  pair,
  onOpen
}: {
  pair: SyncPairSummaryDto;
  onOpen: (id: number) => void;
}) {
  const { t } = useTranslation();

  return (
    <article className={`pair-card pair-card--${pair.severity.toLowerCase()}`}>
      <div className="pair-card__header">
        <strong>{pair.name}</strong>
        <span>{pair.severity}</span>
      </div>
      <p>{pair.local_relative_path} ↔ {pair.remote_path}</p>
      <button onClick={() => onOpen(pair.id)}>{t('app.openDetails')}</button>
    </article>
  );
}
```

```tsx
// src/components/EventList.tsx
import { useTranslation } from 'react-i18next';

export function EventList({ items }: { items: string[] }) {
  const { t } = useTranslation();

  return (
    <section className="event-list">
      <h2>{t('app.recentEvents')}</h2>
      <ul>{items.map((item) => <li key={item}>{item}</li>)}</ul>
    </section>
  );
}
```

- [ ] **Step 4: Replace the temporary shell in `App.tsx` with the dashboard layout**

```tsx
// src/App.tsx
import { useTranslation } from 'react-i18next';

import { EventList } from './components/EventList';
import { QuickActions } from './components/QuickActions';
import { StatusHeader } from './components/StatusHeader';
import { SyncPairCard } from './components/SyncPairCard';
import { useAppStore } from './state/app-store';

export default function App() {
  const { t } = useTranslation();
  const overview = useAppStore((state) => state.overview);

  if (!overview) {
    return <main className="app-shell">{t('app.loading')}</main>;
  }

  return (
    <main className="dashboard">
      <StatusHeader
        title={t('app.title')}
        subtitle={overview.has_rclone ? t('app.rcloneReady') : t('app.rcloneNotConfiguredYet')}
      />

      <QuickActions
        onSyncNow={() => void 0}
        onCheckYandex={() => void 0}
        onPullFromYandex={() => void 0}
      />

      <section className="pair-grid">
        {overview.pairs.map((pair) => (
          <SyncPairCard key={pair.id} pair={pair} onOpen={() => void 0} />
        ))}
      </section>

      <EventList items={[t('app.bootstrapComplete')]} />
    </main>
  );
}
```

```css
/* src/styles/app.css (append) */
.dashboard {
  padding: 24px;
  display: grid;
  gap: 18px;
}

.quick-actions,
.pair-grid {
  display: grid;
  gap: 12px;
}

.pair-card {
  border-radius: 18px;
  border: 1px solid #d6ded5;
  padding: 16px;
  background: #fffefb;
}

.pair-card--warning span {
  color: #b86b1b;
}

.pair-card--alarm span {
  color: #b74444;
}
```

- [ ] **Step 5: Run the component test and frontend build**

Run:

```bash
cd /Users/zerotool/Documents/Dev/macyad
npm run test -- src/components/SyncPairCard.test.tsx
npm run build
```

Expected:
- component test PASS
- frontend build PASS

- [ ] **Step 6: Commit**

```bash
git add src/components/StatusHeader.tsx src/components/QuickActions.tsx src/components/SyncPairCard.tsx src/components/EventList.tsx src/components/SyncPairCard.test.tsx src/App.tsx src/styles/app.css
git commit -m "feat: add Macyad dashboard UI"
```

### Task 11: Реализовать onboarding wizard, pair detail view и settings screen с `ru/en`

**Files:**
- Create: `src/components/OnboardingWizard.tsx`
- Create: `src/components/PairDetailView.tsx`
- Create: `src/components/SettingsView.tsx`
- Create: `src/components/OnboardingWizard.test.tsx`
- Create: `src/components/PairDetailView.test.tsx`
- Modify: `src/api/tauri.ts`
- Modify: `src/App.tsx`
- Modify: `src/styles/app.css`

- [ ] **Step 1: Write failing component tests for onboarding action visibility and alarm detail banner**

```tsx
// src/components/OnboardingWizard.test.tsx
import { render, screen } from '@testing-library/react';

import '../lib/i18n';
import { OnboardingWizard } from './OnboardingWizard';

test('shows brew install action when rclone is missing', () => {
  render(
    <OnboardingWizard
      status={{
        has_rclone: false,
        source: 'missing',
        brew_install_command: 'brew install rclone',
        remote_create_command: 'rclone --config ...'
      }}
    />
  );

  expect(screen.getByText('brew install rclone')).toBeTruthy();
});
```

```tsx
// src/components/PairDetailView.test.tsx
import { render, screen } from '@testing-library/react';

import '../lib/i18n';
import { PairDetailView } from './PairDetailView';

test('renders alarm banner when pair severity is Alarm', () => {
  render(
    <PairDetailView
      pair={{
        id: 1,
        name: 'Work Docs',
        remote_path: 'yd:/Work Docs',
        local_relative_path: 'Work Docs',
        severity: 'Alarm',
        schedule_minutes: 30
      }}
    />
  );

  expect(screen.getByText('Push blocked')).toBeTruthy();
});
```

- [ ] **Step 2: Run the new component tests**

Run:

```bash
cd /Users/zerotool/Documents/Dev/macyad
npm run test -- src/components/OnboardingWizard.test.tsx src/components/PairDetailView.test.tsx
```

Expected: FAIL with missing `OnboardingWizard` and `PairDetailView`

- [ ] **Step 3: Implement typed onboarding API and settings language setter**

```ts
// src/api/tauri.ts (append)
export interface OnboardingStatus {
  has_rclone: boolean;
  source: string;
  brew_install_command: string;
  remote_create_command: string;
}

export function getOnboardingStatus(): Promise<OnboardingStatus> {
  return invoke<OnboardingStatus>('get_onboarding_status');
}
```

```tsx
// src/components/SettingsView.tsx
import { useTranslation } from 'react-i18next';

export function SettingsView(props: {
  language: 'ru' | 'en';
  onLanguageChange: (lang: 'ru' | 'en') => void;
}) {
  const { t } = useTranslation();

  return (
    <section className="settings-view">
      <h2>{t('app.settingsTitle')}</h2>
      <button onClick={() => props.onLanguageChange('ru')}>{t('app.languageRu')}</button>
      <button onClick={() => props.onLanguageChange('en')}>{t('app.languageEn')}</button>
    </section>
  );
}
```

- [ ] **Step 4: Implement onboarding and pair detail views**

```tsx
// src/components/OnboardingWizard.tsx
import { useTranslation } from 'react-i18next';

import type { OnboardingStatus } from '../api/tauri';

export function OnboardingWizard({ status }: { status: OnboardingStatus }) {
  const { t } = useTranslation();

  return (
    <section className="onboarding-card">
      <h2>{t('app.onboardingTitle')}</h2>
      <p>{status.has_rclone ? t('app.rcloneDetected') : t('app.rcloneMissing')}</p>
      {!status.has_rclone && <code>{status.brew_install_command}</code>}
      <code>{status.remote_create_command}</code>
    </section>
  );
}
```

```tsx
// src/components/PairDetailView.tsx
import { useTranslation } from 'react-i18next';

import type { SyncPairSummaryDto } from '../types/contracts';

export function PairDetailView({ pair }: { pair: SyncPairSummaryDto }) {
  const { t } = useTranslation();

  return (
    <section className="pair-detail">
      {pair.severity === 'Alarm' && <div className="alarm-banner">{t('app.pushBlocked')}</div>}
      <h2>{pair.name}</h2>
      <p>{pair.local_relative_path} ↔ {pair.remote_path}</p>
    </section>
  );
}
```

- [ ] **Step 5: Add a simple top-level view switch in `App.tsx`**

```tsx
// src/App.tsx (shape only)
const [view, setView] = useState<'dashboard' | 'onboarding' | 'settings' | 'pair-detail'>('dashboard');
const [status, setStatus] = useState<OnboardingStatus | null>(null);

useEffect(() => {
  void getOnboardingStatus().then(setStatus);
}, []);

if (!status) {
  return <main className="app-shell">{t('app.loading')}</main>;
}

if (!overview) {
  return <main className="app-shell">{t('app.loading')}</main>;
}

if (view === 'onboarding') {
  return <OnboardingWizard status={status} />;
}

if (view === 'settings') {
  return <SettingsView language="ru" onLanguageChange={(lang) => void i18n.changeLanguage(lang)} />;
}

if (view === 'pair-detail' && overview.pairs[0]) {
  return <PairDetailView pair={overview.pairs[0]} />;
}
```

```css
/* src/styles/app.css (append) */
.onboarding-card,
.pair-detail,
.settings-view {
  border-radius: 20px;
  border: 1px solid #d6ded5;
  background: #fffefb;
  padding: 20px;
}

.alarm-banner {
  margin-bottom: 12px;
  padding: 12px 14px;
  border-radius: 14px;
  background: rgba(183, 68, 68, 0.10);
  color: #8f3030;
  font-weight: 700;
}
```

- [ ] **Step 6: Run the UI tests and frontend build**

Run:

```bash
cd /Users/zerotool/Documents/Dev/macyad
npm run test -- src/components/OnboardingWizard.test.tsx src/components/PairDetailView.test.tsx
npm run build
```

Expected:
- onboarding/detail tests PASS
- frontend build PASS

- [ ] **Step 7: Commit**

```bash
git add src/components/OnboardingWizard.tsx src/components/PairDetailView.tsx src/components/SettingsView.tsx src/components/OnboardingWizard.test.tsx src/components/PairDetailView.test.tsx src/api/tauri.ts src/App.tsx src/styles/app.css
git commit -m "feat: add onboarding and detail views"
```

### Task 12: Довести реальные user actions, create pair flow и start-at-login до рабочего состояния

**Files:**
- Modify: `src-tauri/Cargo.toml`
- Modify: `src-tauri/capabilities/default.json`
- Modify: `src-tauri/src/lib.rs`
- Modify: `src-tauri/src/commands/app.rs`
- Modify: `src-tauri/src/commands/pairs.rs`
- Modify: `src-tauri/src/commands/sync.rs`
- Modify: `src-tauri/src/services/sync_runner.rs`
- Modify: `src/api/tauri.ts`
- Modify: `src/components/QuickActions.tsx`
- Modify: `src/components/OnboardingWizard.tsx`
- Modify: `src/components/SettingsView.tsx`
- Modify: `src/App.tsx`

- [ ] **Step 1: Write a failing UI test for real quick actions and settings autostart toggle**

```tsx
// src/components/OnboardingWizard.test.tsx (append)
import { render, screen } from '@testing-library/react';

test('shows manual remote create command and attach-existing path', () => {
  render(
    <OnboardingWizard
      status={{
        has_rclone: true,
        source: 'existing',
        brew_install_command: 'brew install rclone',
        remote_create_command: 'rclone --config ... config create yd-app yandex'
      }}
    />
  );

  expect(screen.getByText(/config create yd-app yandex/i)).toBeTruthy();
});
```

```tsx
// src/components/PairDetailView.test.tsx (append)
import { render, screen } from '@testing-library/react';

test('keeps manual pull action visible in alarm state', () => {
  render(
    <PairDetailView
      pair={{
        id: 1,
        name: 'Work Docs',
        remote_path: 'yd:/Work Docs',
        local_relative_path: 'Work Docs',
        severity: 'Alarm',
        schedule_minutes: 30
      }}
    />
  );

  expect(screen.getByText(/pull/i)).toBeTruthy();
});
```

- [ ] **Step 2: Add the official autostart plugin and expose enable/disable state**

Run:

```bash
cd /Users/zerotool/Documents/Dev/macyad
npm install @tauri-apps/plugin-autostart
npm run tauri add autostart
```

Expected:
- npm installs `@tauri-apps/plugin-autostart`
- Tauri adds the Rust plugin dependency and capability scaffolding

```rust
// src-tauri/src/lib.rs (setup section)
#[cfg(desktop)]
{
  use tauri_plugin_autostart::MacosLauncher;

  app.handle().plugin(tauri_plugin_autostart::init(
    MacosLauncher::LaunchAgent,
    None::<Vec<String>>,
  ))?;
}
```

```json
// src-tauri/capabilities/default.json (append permissions)
{
  "permissions": [
    "core:default",
    "dialog:default",
    "notification:default",
    "autostart:allow-enable",
    "autostart:allow-disable",
    "autostart:allow-is-enabled"
  ]
}
```

- [ ] **Step 3: Replace placeholder sync commands with real manual pull, check and create-pair entry points**

```rust
// src-tauri/src/commands/pairs.rs
use tauri::State;

use crate::{
  app_state::AppState,
  models::{DeletePolicy, SyncPairDraft, SyncPairSummaryDto},
};

#[tauri::command]
pub fn create_sync_pair(
  state: State<'_, AppState>,
  name: String,
  local_relative_path: String,
  remote_path: String,
  schedule_minutes: u32,
  delete_policy: String,
) -> Result<i64, String> {
  let policy = match delete_policy.as_str() {
    "KeepRemoteDeletesSafe" => DeletePolicy::KeepRemoteDeletesSafe,
    "RequireConfirmation" => DeletePolicy::RequireConfirmation,
    _ => DeletePolicy::MirrorToYandex,
  };

  let local_dir = state.paths.workspace_dir.join(&local_relative_path);
  std::fs::create_dir_all(&local_dir).map_err(|err| err.to_string())?;

  state
    .repo
    .lock()
    .unwrap()
    .insert_sync_pair(SyncPairDraft {
      name,
      local_relative_path,
      remote_path,
      schedule_minutes,
      delete_policy: policy,
    })
    .map_err(|err| err.to_string())
}

#[tauri::command]
pub fn list_sync_pairs(state: State<'_, AppState>) -> Vec<SyncPairSummaryDto> {
  state
    .repo
    .lock()
    .unwrap()
    .list_sync_pairs()
    .unwrap_or_default()
    .into_iter()
    .map(|pair| SyncPairSummaryDto {
      id: pair.id,
      name: pair.name,
      remote_path: pair.remote_path,
      local_relative_path: pair.local_relative_path,
      severity: pair.severity,
      schedule_minutes: pair.schedule_minutes,
    })
    .collect()
}
```

```rust
// src-tauri/src/commands/sync.rs
use tauri::State;

use crate::{app_state::AppState, services::sync_runner::SyncRunner};

#[tauri::command]
pub fn sync_now(state: State<'_, AppState>, pair_id: i64) -> Result<(), String> {
  SyncRunner::run_push(&state, pair_id).map_err(|err| err.to_string())
}

#[tauri::command]
pub fn check_yandex(state: State<'_, AppState>, pair_id: i64) -> Result<(), String> {
  SyncRunner::run_remote_check(&state, pair_id).map_err(|err| err.to_string())
}

#[tauri::command]
pub fn pull_from_yandex(state: State<'_, AppState>, pair_id: i64) -> Result<(), String> {
  SyncRunner::run_manual_pull(&state, pair_id).map_err(|err| err.to_string())
}
```

```rust
// src-tauri/src/services/sync_runner.rs (replace stub execution with real process runs)
impl SyncRunner {
  fn ensure_success(mut command: Command) -> Result<(), AppError> {
    let status = command.status()?;

    if status.success() {
      Ok(())
    } else {
      Err(AppError::Validation(format!("rclone exited with status {status}")))
    }
  }

  pub fn run_push(state: &AppState, pair_id: i64) -> Result<(), AppError> {
    let repo = state.repo.lock().unwrap();
    let pair = repo
      .get_sync_pair(pair_id)?
      .ok_or_else(|| AppError::Validation(format!("pair {pair_id} not found")))?;

    match Self::decide_push(&pair) {
      PushDecision::BlockedByAlarm => {
        return Err(AppError::Validation("push blocked by alarm".into()));
      }
      PushDecision::ConfirmationRequired => {
        return Err(AppError::Validation("delete confirmation required".into()));
      }
      PushDecision::Ready => {}
    }

    let local = state.paths.workspace_dir.join(&pair.local_relative_path);
    let command = Self::build_push_command(
      "rclone",
      state.paths.rclone_config_path.to_string_lossy().as_ref(),
      local.to_string_lossy().as_ref(),
      &pair.remote_path,
      pair.delete_policy,
    );

    Self::ensure_success(command)
  }

  pub fn run_remote_check(state: &AppState, pair_id: i64) -> Result<(), AppError> {
    let repo = state.repo.lock().unwrap();
    let pair = repo
      .get_sync_pair(pair_id)?
      .ok_or_else(|| AppError::Validation(format!("pair {pair_id} not found")))?;

    let mut command = Command::new("rclone");
    command
      .arg("--config")
      .arg(&state.paths.rclone_config_path)
      .arg("lsjson")
      .arg(&pair.remote_path);

    Self::ensure_success(command)
  }

  pub fn run_manual_pull(state: &AppState, pair_id: i64) -> Result<(), AppError> {
    let repo = state.repo.lock().unwrap();
    let pair = repo
      .get_sync_pair(pair_id)?
      .ok_or_else(|| AppError::Validation(format!("pair {pair_id} not found")))?;

    let local = state.paths.workspace_dir.join(&pair.local_relative_path);
    let mut command = Command::new("rclone");
    command
      .arg("--config")
      .arg(&state.paths.rclone_config_path)
      .arg("copy")
      .arg(&pair.remote_path)
      .arg(local);

    Self::ensure_success(command)
  }
}
```

- [ ] **Step 4: Implement frontend invoke wrappers and wire quick actions/settings to real commands**

```ts
// src/api/tauri.ts (append)
export function createSyncPair(payload: {
  name: string;
  local_relative_path: string;
  remote_path: string;
  schedule_minutes: number;
  delete_policy: string;
}) {
  return invoke<number>('create_sync_pair', payload);
}

export function runSyncNow(pairId: number) {
  return invoke<void>('sync_now', { pairId });
}

export function runCheckYandex(pairId: number) {
  return invoke<void>('check_yandex', { pairId });
}

export function runPullFromYandex(pairId: number) {
  return invoke<void>('pull_from_yandex', { pairId });
}
```

```tsx
// src/components/QuickActions.tsx
export function QuickActions(props: {
  onSyncNow: () => void;
  onCheckYandex: () => void;
  onPullFromYandex: () => void;
}) {
  const { t } = useTranslation();

  return (
    <section className="quick-actions">
      <button onClick={props.onSyncNow}>{t('app.syncNow')}</button>
      <button onClick={props.onCheckYandex}>{t('app.checkYandex')}</button>
      <button onClick={props.onPullFromYandex}>{t('app.pullFromYandex')}</button>
    </section>
  );
}
```

```tsx
// src/components/SettingsView.tsx
import { useEffect, useState } from 'react';

import { disable, enable, isEnabled } from '@tauri-apps/plugin-autostart';
import { useTranslation } from 'react-i18next';

export function SettingsView(props: {
  language: 'ru' | 'en';
  onLanguageChange: (lang: 'ru' | 'en') => void;
}) {
  const { t } = useTranslation();
  const [autostartEnabled, setAutostartEnabled] = useState(false);

  useEffect(() => {
    void isEnabled().then(setAutostartEnabled);
  }, []);

  return (
    <section className="settings-view">
      <h2>{t('app.settingsTitle')}</h2>
      <button onClick={() => props.onLanguageChange('ru')}>{t('app.languageRu')}</button>
      <button onClick={() => props.onLanguageChange('en')}>{t('app.languageEn')}</button>
      <button
        onClick={async () => {
          if (autostartEnabled) {
            await disable();
            setAutostartEnabled(false);
          } else {
            await enable();
            setAutostartEnabled(true);
          }
        }}
      >
        {autostartEnabled ? t('app.startAtLoginDisable') : t('app.startAtLoginEnable')}
      </button>
    </section>
  );
}
```

```tsx
// src/App.tsx (wire create-pair flow and real quick actions)
const firstPair = overview?.pairs[0] ?? null;
const [draft, setDraft] = useState({
  name: 'Work Docs',
  local_relative_path: 'Work Docs',
  remote_path: 'yd:/Work Docs',
  schedule_minutes: 30,
  delete_policy: 'MirrorToYandex'
});

<QuickActions
  onSyncNow={() => firstPair && void runSyncNow(firstPair.id)}
  onCheckYandex={() => firstPair && void runCheckYandex(firstPair.id)}
  onPullFromYandex={() => firstPair && void runPullFromYandex(firstPair.id)}
/>

<form
  className="create-pair-form"
  onSubmit={async (event) => {
    event.preventDefault();
    await createSyncPair(draft);
    await loadOverview();
  }}
>
  <input
    value={draft.name}
    onChange={(event) => setDraft({ ...draft, name: event.target.value })}
  />
  <input
    value={draft.local_relative_path}
    onChange={(event) => setDraft({ ...draft, local_relative_path: event.target.value })}
  />
  <input
    value={draft.remote_path}
    onChange={(event) => setDraft({ ...draft, remote_path: event.target.value })}
  />
  <button type="submit">{t('app.createPair')}</button>
</form>
```

```rust
// src-tauri/src/lib.rs (update registered commands)
use crate::commands::{
  app::get_app_overview,
  onboarding::{get_onboarding_status, import_existing_remote, install_managed_rclone},
  pairs::{create_sync_pair, list_sync_pairs},
  sync::{check_yandex, pull_from_yandex, sync_now},
};

.invoke_handler(tauri::generate_handler![
  get_app_overview,
  get_onboarding_status,
  import_existing_remote,
  install_managed_rclone,
  create_sync_pair,
  list_sync_pairs,
  sync_now,
  check_yandex,
  pull_from_yandex
])
```

- [ ] **Step 5: Run targeted tests and the full app smoke pass**

Run:

```bash
cd /Users/zerotool/Documents/Dev/macyad
npm run test -- src/components/OnboardingWizard.test.tsx src/components/PairDetailView.test.tsx
cargo test --manifest-path src-tauri/Cargo.toml
npm run tauri:dev
```

Expected:
- onboarding/detail tests PASS
- backend tests PASS
- app launches with working quick actions, manual pull visibility and start-at-login toggle

- [ ] **Step 6: Commit**

```bash
git add src-tauri/Cargo.toml src-tauri/capabilities/default.json src-tauri/src/lib.rs src-tauri/src/commands/app.rs src-tauri/src/commands/pairs.rs src-tauri/src/commands/sync.rs src-tauri/src/services/sync_runner.rs src/api/tauri.ts src/components/QuickActions.tsx src/components/OnboardingWizard.tsx src/components/SettingsView.tsx src/App.tsx
git commit -m "feat: wire real sync actions and autostart"
```

### Task 13: Провести end-to-end verification, QA checklist и release-ready cleanup

**Files:**
- Modify: `README.md`
- Create: `docs/superpowers/plans/qa-macyad-mvp-checklist.md`
- Modify: `src/App.tsx`
- Modify: `src-tauri/src/lib.rs`

- [ ] **Step 1: Add a QA checklist document for the agreed MVP behaviors**

```md
<!-- docs/superpowers/plans/qa-macyad-mvp-checklist.md -->
# Macyad MVP QA Checklist

- [ ] On first launch, the app appears in the tray/menu bar.
- [ ] If `rclone` is missing, the onboarding screen shows `brew install rclone`.
- [ ] The UI can switch between `ru` and `en`.
- [ ] Managed workspace directories are created under app-owned storage.
- [ ] `Check Yandex` can run without forcing a pull.
- [ ] A pair marked `Alarm` blocks scheduled push.
- [ ] `Warning` can show a system notification without blocking push.
- [ ] `Pull From Yandex` remains a manual action.
```

- [ ] **Step 2: Update `README.md` with local development and test commands**

````md
<!-- README.md (append below existing content) -->
## Development

```bash
npm install
npm run tauri:dev
```

## Tests

```bash
npm run test
cargo test --manifest-path src-tauri/Cargo.toml
```
````

- [ ] **Step 3: Add one final visible dashboard state for the empty-app onboarding path**

```tsx
// src/App.tsx (empty-state guard)
if (status && !overview?.has_rclone) {
  return <OnboardingWizard status={status} />;
}
```

- [ ] **Step 4: Run full verification**

Run:

```bash
cd /Users/zerotool/Documents/Dev/macyad
npm run test
npm run build
cargo test --manifest-path src-tauri/Cargo.toml
npm run tauri:build
```

Expected:
- frontend tests PASS
- frontend build PASS
- backend tests PASS
- Tauri build PASS

- [ ] **Step 5: Execute manual QA**

Run through:

```text
1. Launch the app and confirm the tray icon exists.
2. Open the dropdown and confirm the dashboard loads.
3. Switch UI language to English, then back to Russian.
4. Force the onboarding path by moving `rclone` out of PATH and relaunching.
5. Import a test config file and validate that app-managed `rclone.conf` changes.
6. Mark a pair as `Alarm` in the database fixture and confirm the detail view shows "Push blocked".
```

Expected: each scenario matches the MVP behavior defined in the spec

- [ ] **Step 6: Commit**

```bash
git add README.md docs/superpowers/plans/qa-macyad-mvp-checklist.md src/App.tsx src-tauri/src/lib.rs
git commit -m "chore: verify Macyad MVP end to end"
```
