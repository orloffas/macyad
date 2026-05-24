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
