use macyad_lib::{
    db::Repository,
    models::{validate_local_relative_path, DeletePolicy, PairSeverity, SyncPairDraft},
};

#[test]
fn migrates_schema_and_inserts_default_settings() {
    let dir = tempfile::tempdir().unwrap();
    let repo = Repository::open(dir.path().join("macyad.db")).unwrap();

    let settings = repo.load_settings().unwrap();
    assert_eq!(settings.ui_language, "ru");
    assert_eq!(settings.default_schedule_minutes, 30);
}

#[test]
fn creates_and_reads_sync_pair() {
    let dir = tempfile::tempdir().unwrap();
    let repo = Repository::open(dir.path().join("macyad.db")).unwrap();

    let pair_id = repo
        .insert_sync_pair(SyncPairDraft {
            name: "Work Docs".into(),
            local_relative_path: "Work Docs".into(),
            remote_path: "yd:/Work Docs".into(),
            schedule_minutes: 30,
            delete_policy: DeletePolicy::MirrorToYandex,
        })
        .unwrap();

    let pair = repo.get_sync_pair(pair_id).unwrap().unwrap();
    assert_eq!(pair.name, "Work Docs");
    assert_eq!(pair.severity, PairSeverity::Healthy);

    let pairs = repo.list_sync_pairs().unwrap();
    assert_eq!(pairs.len(), 1);
}

#[test]
fn updates_ui_language_setting() {
    let dir = tempfile::tempdir().unwrap();
    let repo = Repository::open(dir.path().join("macyad.db")).unwrap();

    repo.update_ui_language("en").unwrap();

    let settings = repo.load_settings().unwrap();
    assert_eq!(settings.ui_language, "en");
}

#[test]
fn rejects_paths_that_escape_managed_workspace() {
    assert!(validate_local_relative_path("../outside").is_err());
    assert!(validate_local_relative_path("/tmp/outside").is_err());
    assert!(validate_local_relative_path("Nested/Docs").is_ok());
}
