use std::process::Command;

use macyad_lib::{
    models::{DeletePolicy, PairSeverity, SyncPair},
    services::{
        notifications::should_send_system_notification,
        scheduler::RunLock,
        sync_runner::{PushDecision, SyncRunner},
    },
};

fn command_args(command: &Command) -> Vec<String> {
    command
        .get_args()
        .map(|arg| arg.to_string_lossy().into_owned())
        .collect()
}

#[test]
fn blocks_scheduled_push_when_alarm_is_present() {
    let pair = SyncPair {
        id: 1,
        name: "Work Docs".into(),
        local_relative_path: "Work Docs".into(),
        remote_path: "yd:/Work Docs".into(),
        schedule_minutes: 30,
        delete_policy: DeletePolicy::MirrorToYandex,
        severity: PairSeverity::Alarm,
    };

    let decision = SyncRunner::decide_push(&pair);
    assert_eq!(decision, PushDecision::BlockedByAlarm);
}

#[test]
fn builds_initial_pull_command_from_yandex_into_workspace() {
    let command = SyncRunner::build_pull_command(
        "rclone",
        "/tmp/rclone.conf",
        "yd:/Work Docs",
        "/tmp/workspace/Work Docs",
    );

    let args = command_args(&command);
    assert_eq!(
        args,
        vec![
            "--config",
            "/tmp/rclone.conf",
            "copy",
            "yd:/Work Docs",
            "/tmp/workspace/Work Docs",
            "--create-empty-src-dirs",
            "--exclude",
            ".DS_Store",
            "--exclude",
            "._*",
        ]
    );
}

#[test]
fn removes_scheduler_lock_file_when_guard_is_dropped() {
    let temp = tempfile::tempdir().unwrap();
    let lock_path = temp.path().join("sync.lock");

    {
        let _lock = RunLock::acquire(lock_path.clone()).unwrap();
        assert!(lock_path.exists());
    }

    assert!(!lock_path.exists());
}

#[test]
fn rejects_second_scheduler_lock_while_first_guard_is_alive() {
    let temp = tempfile::tempdir().unwrap();
    let lock_path = temp.path().join("sync.lock");

    let _lock = RunLock::acquire(lock_path.clone()).unwrap();
    let second = RunLock::acquire(lock_path);

    assert!(second.is_err());
}

#[test]
fn sends_system_notifications_only_for_warning_and_alarm() {
    assert!(!should_send_system_notification(PairSeverity::Healthy));
    assert!(!should_send_system_notification(PairSeverity::Info));
    assert!(should_send_system_notification(PairSeverity::Warning));
    assert!(should_send_system_notification(PairSeverity::Alarm));
}
