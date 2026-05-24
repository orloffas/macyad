use tauri::State;

use crate::{
    app_state::AppState,
    models::{AppOverview, SyncPairSummaryDto},
};

#[tauri::command]
pub fn get_app_overview(state: State<'_, AppState>) -> AppOverview {
    let repo = state.repo.lock().unwrap();
    let settings = repo.load_settings().unwrap();
    let pairs = repo
        .list_sync_pairs()
        .unwrap_or_default()
        .into_iter()
        .map(SyncPairSummaryDto::from)
        .collect();

    AppOverview {
        ui_language: settings.ui_language,
        has_rclone: state.paths.managed_bin_dir.join("rclone").exists()
            || which::which("rclone").is_ok(),
        next_push_in_minutes: Some(settings.default_schedule_minutes),
        pairs,
    }
}
