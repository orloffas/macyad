import { invoke } from '@tauri-apps/api/core';

import type { AppOverview } from '../types/contracts';

export interface OnboardingStatus {
  has_rclone: boolean;
  source: string;
  brew_install_command: string;
  remote_create_command: string;
}

export function getAppOverview(): Promise<AppOverview> {
  return invoke<AppOverview>('get_app_overview');
}

export function getOnboardingStatus(): Promise<OnboardingStatus> {
  return invoke<OnboardingStatus>('get_onboarding_status');
}

export function setUiLanguage(language: 'ru' | 'en') {
  return invoke<void>('set_ui_language', { language });
}

export function createSyncPair(payload: {
  name: string;
  local_relative_path: string;
  remote_path: string;
  schedule_minutes: number;
  delete_policy: string;
}) {
  return invoke<number>('create_sync_pair', payload);
}

export function runSyncNow(pairId: number) {
  return invoke<void>('sync_now', { pairId });
}

export function runCheckYandex(pairId: number) {
  return invoke<void>('check_yandex', { pairId });
}

export function runPullFromYandex(pairId: number) {
  return invoke<void>('pull_from_yandex', { pairId });
}
