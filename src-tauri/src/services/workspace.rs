use std::{fs, path::PathBuf};

use crate::{error::AppError, models::AppPaths};

pub struct WorkspaceManager {
    root_dir: PathBuf,
}

impl WorkspaceManager {
    pub fn new(root_dir: PathBuf) -> Self {
        Self { root_dir }
    }

    pub fn ensure_layout(&self) -> Result<AppPaths, AppError> {
        let workspace_dir = self.root_dir.join("workspace");
        let rclone_dir = self.root_dir.join("rclone");
        let managed_bin_dir = rclone_dir.join("bin");
        let rclone_config_path = rclone_dir.join("rclone.conf");
        let database_path = self.root_dir.join("macyad.db");

        fs::create_dir_all(&workspace_dir)?;
        fs::create_dir_all(&managed_bin_dir)?;

        Ok(AppPaths {
            root_dir: self.root_dir.clone(),
            workspace_dir,
            rclone_dir,
            rclone_config_path,
            managed_bin_dir,
            database_path,
        })
    }
}
