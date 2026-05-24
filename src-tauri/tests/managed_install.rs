use std::fs;

use macyad_lib::services::rclone::install_managed_rclone_from_fixture;

#[test]
fn installs_fixture_binary_into_managed_bin_dir() {
    let temp = tempfile::tempdir().unwrap();
    let fixture = temp.path().join("rclone");
    fs::write(&fixture, "#!/bin/sh\necho rclone\n").unwrap();

    let installed =
        install_managed_rclone_from_fixture(&fixture, &temp.path().join("bin")).unwrap();

    assert!(installed.exists());
    assert!(installed.ends_with("bin/rclone"));
}
