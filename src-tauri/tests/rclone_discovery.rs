use std::{fs, path::PathBuf};

use macyad_lib::services::rclone::{RcloneBinary, RcloneResolver};

#[test]
fn prefers_existing_binary_over_managed_download() {
    let temp = tempfile::tempdir().unwrap();
    let existing = temp.path().join("existing-rclone");
    let managed = temp.path().join("managed-rclone");
    fs::write(&existing, "binary").unwrap();
    fs::write(&managed, "binary").unwrap();

    let resolver = RcloneResolver::for_tests(Some(existing.clone()), Some(managed));

    let resolved = resolver.resolve().unwrap();
    assert_eq!(resolved.binary, RcloneBinary::ExistingPath(existing));
}

#[test]
fn ignores_missing_managed_binary_path() {
    let resolver = RcloneResolver::for_tests(None, Some(PathBuf::from("/tmp/macyad/bin/rclone")));

    let resolved = resolver.resolve().unwrap();
    assert_eq!(resolved.binary, RcloneBinary::Missing);
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
