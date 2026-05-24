use std::sync::{Arc, Mutex};

use crate::{db::Repository, error::AppError, models::AppPaths};

pub struct AppState {
    pub repo: Arc<Mutex<Repository>>,
    pub paths: AppPaths,
}

impl AppState {
    pub fn new(repo: Repository, paths: AppPaths) -> Result<Self, AppError> {
        Ok(Self {
            repo: Arc::new(Mutex::new(repo)),
            paths,
        })
    }
}
