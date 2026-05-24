use std::{
    fs,
    path::{Path, PathBuf},
};

use serde::Serialize;

use crate::error::AppError;
use crate::services::rclone::{RcloneBinary, RcloneResolver};

#[derive(Debug, Serialize)]
pub struct OnboardingStatus {
    pub has_rclone: bool,
    pub source: String,
    pub brew_install_command: String,
    pub remote_create_command: String,
}

pub fn onboarding_status(
    config_path: PathBuf,
    existing: Option<PathBuf>,
    managed: Option<PathBuf>,
) -> OnboardingStatus {
    let resolver = RcloneResolver::new(existing, managed);
    let resolved = resolver.resolve().expect("resolver should not fail");

    let (has_rclone, source) = match resolved.binary {
        RcloneBinary::ExistingPath(_) => (true, "existing".to_string()),
        RcloneBinary::ManagedDownload(_) => (true, "managed".to_string()),
        RcloneBinary::Missing => (false, "missing".to_string()),
    };

    OnboardingStatus {
        has_rclone,
        source,
        brew_install_command: "brew install rclone".into(),
        remote_create_command: RcloneResolver::build_remote_create_command(
            config_path.to_string_lossy().as_ref(),
            "yd-app",
        ),
    }
}

pub fn import_existing_remote_config(
    existing_config: &Path,
    target_config: &Path,
) -> Result<(), AppError> {
    let contents = fs::read_to_string(existing_config)?;
    fs::write(target_config, contents)?;
    Ok(())
}
