use std::collections::{BTreeSet, HashMap};

use crate::models::PairSeverity;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FileSnapshot {
    pub path: String,
    pub checksum: String,
    pub size: u64,
}

impl FileSnapshot {
    pub fn new(path: &str, checksum: &str, size: u64) -> Self {
        Self {
            path: path.into(),
            checksum: checksum.into(),
            size,
        }
    }
}

pub fn classify_drift(
    baseline: &[FileSnapshot],
    remote: &[FileSnapshot],
    local: &[FileSnapshot],
) -> PairSeverity {
    let base: HashMap<_, _> = baseline
        .iter()
        .map(|item| (item.path.as_str(), item))
        .collect();
    let remote_map: HashMap<_, _> = remote
        .iter()
        .map(|item| (item.path.as_str(), item))
        .collect();
    let local_map: HashMap<_, _> = local
        .iter()
        .map(|item| (item.path.as_str(), item))
        .collect();

    let mut all_paths = BTreeSet::new();
    all_paths.extend(base.keys().copied());
    all_paths.extend(remote_map.keys().copied());
    all_paths.extend(local_map.keys().copied());

    let mut saw_remote_change = false;
    let mut saw_local_change = false;

    for path in all_paths {
        let baseline_checksum = base.get(path).map(|item| item.checksum.as_str());
        let remote_checksum = remote_map.get(path).map(|item| item.checksum.as_str());
        let local_checksum = local_map.get(path).map(|item| item.checksum.as_str());

        let remote_changed = remote_checksum != baseline_checksum;
        let local_changed = local_checksum != baseline_checksum;

        if remote_changed && local_changed {
            return PairSeverity::Alarm;
        }

        if remote_changed {
            saw_remote_change = true;
        }

        if local_changed {
            saw_local_change = true;
        }
    }

    if saw_remote_change && saw_local_change {
        PairSeverity::Warning
    } else if saw_remote_change {
        PairSeverity::Info
    } else {
        PairSeverity::Healthy
    }
}
