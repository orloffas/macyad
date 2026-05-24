use crate::models::PairSeverity;

pub fn should_send_system_notification(severity: PairSeverity) -> bool {
    matches!(severity, PairSeverity::Warning | PairSeverity::Alarm)
}
