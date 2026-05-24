use std::{
    fs,
    path::{Path, PathBuf},
};

use crate::error::AppError;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum RcloneBinary {
    ExistingPath(PathBuf),
    ManagedDownload(PathBuf),
    Missing,
}

#[derive(Debug, Clone)]
pub struct ResolvedRclone {
    pub binary: RcloneBinary,
}

pub struct RcloneResolver {
    existing_path: Option<PathBuf>,
    managed_path: Option<PathBuf>,
}

impl RcloneResolver {
    pub fn new(existing_path: Option<PathBuf>, managed_path: Option<PathBuf>) -> Self {
        Self {
            existing_path,
            managed_path,
        }
    }

    pub fn for_tests(existing_path: Option<PathBuf>, managed_path: Option<PathBuf>) -> Self {
        Self::new(existing_path, managed_path)
    }

    pub fn resolve(&self) -> Result<ResolvedRclone, AppError> {
        if let Some(path) = &self.existing_path {
            return Ok(ResolvedRclone {
                binary: RcloneBinary::ExistingPath(path.clone()),
            });
        }

        if let Some(path) = &self.managed_path {
            return Ok(ResolvedRclone {
                binary: RcloneBinary::ManagedDownload(path.clone()),
            });
        }

        Ok(ResolvedRclone {
            binary: RcloneBinary::Missing,
        })
    }

    pub fn build_remote_create_command(config_path: &str, remote_name: &str) -> String {
        format!("rclone --config \"{config_path}\" config create {remote_name} yandex")
    }
}

pub fn download_and_install_managed_rclone(
    download_url: &str,
    managed_dir: &Path,
) -> Result<PathBuf, AppError> {
    fs::create_dir_all(managed_dir)?;

    let response = reqwest::blocking::get(download_url)
        .map_err(|err| AppError::Validation(format!("download failed: {err}")))?;
    let bytes = response
        .bytes()
        .map_err(|err| AppError::Validation(format!("download body failed: {err}")))?;

    let cursor = std::io::Cursor::new(bytes);
    let mut archive = zip::ZipArchive::new(cursor)
        .map_err(|err| AppError::Validation(format!("invalid archive: {err}")))?;

    for index in 0..archive.len() {
        let mut file = archive
            .by_index(index)
            .map_err(|err| AppError::Validation(format!("archive read failed: {err}")))?;

        if file.name().ends_with("/rclone") {
            let destination = managed_dir.join("rclone");
            let mut output = fs::File::create(&destination)?;
            std::io::copy(&mut file, &mut output)?;

            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                let mut permissions = fs::metadata(&destination)?.permissions();
                permissions.set_mode(0o755);
                fs::set_permissions(&destination, permissions)?;
            }

            return Ok(destination);
        }
    }

    Err(AppError::Validation(
        "rclone binary not found in archive".into(),
    ))
}

pub fn install_managed_rclone_from_fixture(
    source: &Path,
    managed_dir: &Path,
) -> Result<PathBuf, AppError> {
    fs::create_dir_all(managed_dir)?;
    let destination = managed_dir.join("rclone");
    fs::copy(source, &destination)?;

    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let mut permissions = fs::metadata(&destination)?.permissions();
        permissions.set_mode(0o755);
        fs::set_permissions(&destination, permissions)?;
    }

    Ok(destination)
}
