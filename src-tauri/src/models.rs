use std::path::{Component, Path, PathBuf};

use serde::{Deserialize, Serialize};

use crate::error::AppError;

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

impl SyncPairDraft {
    pub fn validate(&self) -> Result<(), AppError> {
        validate_local_relative_path(&self.local_relative_path)
    }
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

#[derive(Debug, Clone)]
pub struct AppPaths {
    pub root_dir: PathBuf,
    pub workspace_dir: PathBuf,
    pub rclone_dir: PathBuf,
    pub rclone_config_path: PathBuf,
    pub managed_bin_dir: PathBuf,
    pub database_path: PathBuf,
}

#[derive(Debug, Clone, Serialize)]
pub struct SyncPairSummaryDto {
    pub id: i64,
    pub name: String,
    pub remote_path: String,
    pub local_relative_path: String,
    pub severity: PairSeverity,
    pub schedule_minutes: u32,
}

impl From<SyncPair> for SyncPairSummaryDto {
    fn from(value: SyncPair) -> Self {
        Self {
            id: value.id,
            name: value.name,
            remote_path: value.remote_path,
            local_relative_path: value.local_relative_path,
            severity: value.severity,
            schedule_minutes: value.schedule_minutes,
        }
    }
}

#[derive(Debug, Clone, Serialize)]
pub struct AppOverview {
    pub ui_language: String,
    pub has_rclone: bool,
    pub next_push_in_minutes: Option<u32>,
    pub pairs: Vec<SyncPairSummaryDto>,
}

pub fn validate_local_relative_path(path: &str) -> Result<(), AppError> {
    if path.trim().is_empty() {
        return Err(AppError::Validation("local path must not be empty".into()));
    }

    let candidate = Path::new(path);
    if candidate.is_absolute() {
        return Err(AppError::Validation(
            "local path must stay inside the managed workspace".into(),
        ));
    }

    let mut has_normal_component = false;
    for component in candidate.components() {
        match component {
            Component::Normal(_) => has_normal_component = true,
            Component::CurDir
            | Component::ParentDir
            | Component::RootDir
            | Component::Prefix(_) => {
                return Err(AppError::Validation(
                    "local path must stay inside the managed workspace".into(),
                ));
            }
        }
    }

    if !has_normal_component {
        return Err(AppError::Validation(
            "local path must stay inside the managed workspace".into(),
        ));
    }

    Ok(())
}
