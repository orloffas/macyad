pub mod app_state;
pub mod commands;
pub mod db;
pub mod error;
pub mod models;
pub mod services;

use crate::{
    app_state::AppState,
    commands::{
        app::{get_app_overview, set_ui_language},
        onboarding::{get_onboarding_status, import_existing_remote, install_managed_rclone},
        pairs::{create_sync_pair, list_sync_pairs},
        sync::{check_yandex, pull_from_yandex, sync_now},
    },
    db::Repository,
    services::workspace::WorkspaceManager,
};
use tauri::{
    menu::{Menu, MenuItem},
    tray::TrayIconBuilder,
    Manager,
};

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_autostart::init(
            tauri_plugin_autostart::MacosLauncher::LaunchAgent,
            None::<Vec<&str>>,
        ))
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_notification::init())
        .invoke_handler(tauri::generate_handler![
            get_app_overview,
            get_onboarding_status,
            import_existing_remote,
            install_managed_rclone,
            create_sync_pair,
            list_sync_pairs,
            sync_now,
            check_yandex,
            pull_from_yandex,
            set_ui_language
        ])
        .setup(|app| {
            let app_root = app.path().app_data_dir()?.join("macyad");
            let paths = WorkspaceManager::new(app_root)
                .ensure_layout()
                .map_err(io_error)?;
            let repo = Repository::open(paths.database_path.clone()).map_err(io_error)?;
            let state = AppState::new(repo, paths).map_err(io_error)?;
            app.manage(state);

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

fn io_error(err: impl std::fmt::Display) -> std::io::Error {
    std::io::Error::other(err.to_string())
}
