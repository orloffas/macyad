use tauri::State;

use crate::{
    app_state::AppState,
    services::{
        onboarding::{import_existing_remote_config, onboarding_status, OnboardingStatus},
        rclone::{download_and_install_managed_rclone, install_managed_rclone_from_fixture},
    },
};

#[tauri::command]
pub fn get_onboarding_status(state: State<'_, AppState>) -> OnboardingStatus {
    let managed_path = state.paths.managed_bin_dir.join("rclone");

    onboarding_status(
        state.paths.rclone_config_path.clone(),
        which::which("rclone").ok(),
        managed_path.exists().then_some(managed_path),
    )
}

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
pub fn import_existing_remote(
    state: State<'_, AppState>,
    existing_config: String,
) -> Result<(), String> {
    import_existing_remote_config(
        std::path::Path::new(&existing_config),
        &state.paths.rclone_config_path,
    )
    .map_err(|err| err.to_string())
}
