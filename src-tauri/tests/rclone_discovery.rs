use std::path::PathBuf;

use macyad_lib::services::rclone::{RcloneBinary, RcloneResolver};

#[test]
fn prefers_existing_binary_over_managed_download() {
    let resolver = RcloneResolver::for_tests(
        Some(PathBuf::from("/opt/homebrew/bin/rclone")),
        Some(PathBuf::from("/tmp/macyad/bin/rclone")),
    );

    let resolved = resolver.resolve().unwrap();
    assert_eq!(
        resolved.binary,
        RcloneBinary::ExistingPath(PathBuf::from("/opt/homebrew/bin/rclone"))
    );
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
