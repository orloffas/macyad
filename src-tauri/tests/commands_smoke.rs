use macyad_lib::models::AppOverview;

#[test]
fn app_overview_defaults_to_ru_and_empty_pairs() {
    let overview = AppOverview {
        ui_language: "ru".into(),
        has_rclone: false,
        next_push_in_minutes: None,
        pairs: vec![],
    };

    assert_eq!(overview.ui_language, "ru");
    assert!(overview.pairs.is_empty());
}
