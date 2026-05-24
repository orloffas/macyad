use tauri::State;

use crate::{
    app_state::AppState,
    models::{validate_local_relative_path, DeletePolicy, SyncPairDraft, SyncPairSummaryDto},
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
    validate_local_relative_path(&local_relative_path).map_err(|err| err.to_string())?;

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
        .map(SyncPairSummaryDto::from)
        .collect()
}
