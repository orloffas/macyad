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
        draft.validate()?;

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

    pub fn update_ui_language(&self, language: &str) -> Result<(), AppError> {
        self.conn.execute(
            "update app_settings set ui_language = ?1 where id = 1",
            [language],
        )?;

        Ok(())
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
