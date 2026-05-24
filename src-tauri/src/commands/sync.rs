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
