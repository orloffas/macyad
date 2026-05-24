use std::{
    fs::{self, OpenOptions},
    io::Write,
    path::PathBuf,
};

use crate::error::AppError;

pub struct RunLock {
    path: PathBuf,
}

impl RunLock {
    pub fn acquire(path: PathBuf) -> Result<Self, AppError> {
        let mut file = OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&path)?;
        file.write_all(b"locked")?;
        Ok(Self { path })
    }
}

impl Drop for RunLock {
    fn drop(&mut self) {
        let _ = fs::remove_file(&self.path);
    }
}
