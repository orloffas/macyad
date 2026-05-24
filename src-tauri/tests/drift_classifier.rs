use macyad_lib::{
    models::PairSeverity,
    services::drift::{classify_drift, FileSnapshot},
};

#[test]
fn classifies_remote_only_change_as_info() {
    let severity = classify_drift(
        &[FileSnapshot::new("notes/todo.txt", "a", 10)],
        &[FileSnapshot::new("notes/todo.txt", "b", 10)],
        &[FileSnapshot::new("notes/todo.txt", "a", 10)],
    );

    assert_eq!(severity, PairSeverity::Info);
}

#[test]
fn classifies_general_divergence_as_warning() {
    let severity = classify_drift(
        &[FileSnapshot::new("a.txt", "a", 10)],
        &[
            FileSnapshot::new("a.txt", "a", 10),
            FileSnapshot::new("b.txt", "b", 12),
        ],
        &[FileSnapshot::new("a.txt", "x", 10)],
    );

    assert_eq!(severity, PairSeverity::Warning);
}

#[test]
fn classifies_same_object_change_as_alarm() {
    let severity = classify_drift(
        &[FileSnapshot::new("proposal.docx", "old", 10)],
        &[FileSnapshot::new("proposal.docx", "remote", 11)],
        &[FileSnapshot::new("proposal.docx", "local", 12)],
    );

    assert_eq!(severity, PairSeverity::Alarm);
}
