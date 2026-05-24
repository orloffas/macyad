use std::{path::Path, process::Command};

use crate::{
    app_state::AppState,
    error::AppError,
    models::{DeletePolicy, PairSeverity, SyncPair},
    services::rclone::{RcloneBinary, RcloneResolver},
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

    pub fn build_push_command(
        binary: &str,
        config_path: &str,
        local: &str,
        remote: &str,
        policy: DeletePolicy,
    ) -> Command {
        let mut command = Self::base_command(binary, config_path);

        match policy {
            DeletePolicy::MirrorToYandex => {
                command.arg("sync").arg(local).arg(remote);
            }
            DeletePolicy::KeepRemoteDeletesSafe | DeletePolicy::RequireConfirmation => {
                command.arg("copy").arg(local).arg(remote);
            }
        }

        Self::apply_common_filters(command)
    }

    pub fn build_pull_command(
        binary: &str,
        config_path: &str,
        remote: &str,
        local: &str,
    ) -> Command {
        let mut command = Self::base_command(binary, config_path);
        command.arg("copy").arg(remote).arg(local);
        Self::apply_common_filters(command)
    }

    pub fn run_push(state: &AppState, pair_id: i64) -> Result<(), AppError> {
        let pair = Self::load_pair(state, pair_id)?;

        match Self::decide_push(&pair) {
            PushDecision::BlockedByAlarm => {
                return Err(AppError::Validation("push blocked by alarm".into()));
            }
            PushDecision::ConfirmationRequired => {
                return Err(AppError::Validation("delete confirmation required".into()));
            }
            PushDecision::Ready => {}
        }

        let binary = Self::resolve_binary_path(state)?;
        let local = state.paths.workspace_dir.join(&pair.local_relative_path);
        let command = Self::build_push_command(
            &binary,
            state.paths.rclone_config_path.to_string_lossy().as_ref(),
            local.to_string_lossy().as_ref(),
            &pair.remote_path,
            pair.delete_policy,
        );

        Self::ensure_success(command)
    }

    pub fn run_remote_check(state: &AppState, pair_id: i64) -> Result<(), AppError> {
        let pair = Self::load_pair(state, pair_id)?;
        let binary = Self::resolve_binary_path(state)?;
        let mut command = Self::base_command(
            &binary,
            state.paths.rclone_config_path.to_string_lossy().as_ref(),
        );
        command.arg("lsjson").arg(&pair.remote_path);
        Self::ensure_success(command)
    }

    pub fn run_manual_pull(state: &AppState, pair_id: i64) -> Result<(), AppError> {
        let pair = Self::load_pair(state, pair_id)?;
        let binary = Self::resolve_binary_path(state)?;
        let local = state.paths.workspace_dir.join(&pair.local_relative_path);
        let command = Self::build_pull_command(
            &binary,
            state.paths.rclone_config_path.to_string_lossy().as_ref(),
            &pair.remote_path,
            local.to_string_lossy().as_ref(),
        );

        Self::ensure_success(command)
    }

    fn load_pair(state: &AppState, pair_id: i64) -> Result<SyncPair, AppError> {
        let repo = state.repo.lock().unwrap();
        repo.get_sync_pair(pair_id)?
            .ok_or_else(|| AppError::Validation(format!("pair {pair_id} not found")))
    }

    fn resolve_binary_path(state: &AppState) -> Result<String, AppError> {
        let managed_path = state.paths.managed_bin_dir.join("rclone");
        let managed = managed_path.exists().then_some(managed_path);
        let resolver = RcloneResolver::new(which::which("rclone").ok(), managed);
        let resolved = resolver.resolve()?;

        match resolved.binary {
            RcloneBinary::ExistingPath(path) | RcloneBinary::ManagedDownload(path) => {
                Ok(path_to_string(path.as_path()))
            }
            RcloneBinary::Missing => Err(AppError::Validation(
                "rclone binary is not available".into(),
            )),
        }
    }

    fn base_command(binary: &str, config_path: &str) -> Command {
        let mut command = Command::new(binary);
        command.arg("--config").arg(config_path);
        command
    }

    fn apply_common_filters(mut command: Command) -> Command {
        command
            .arg("--create-empty-src-dirs")
            .arg("--exclude")
            .arg(".DS_Store")
            .arg("--exclude")
            .arg("._*");
        command
    }

    fn ensure_success(mut command: Command) -> Result<(), AppError> {
        let status = command.status()?;

        if status.success() {
            Ok(())
        } else {
            Err(AppError::Validation(format!(
                "rclone exited with status {status}"
            )))
        }
    }
}

fn path_to_string(path: &Path) -> String {
    path.to_string_lossy().into_owned()
}
