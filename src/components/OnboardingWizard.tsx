import { useTranslation } from 'react-i18next';

import type { OnboardingStatus } from '../api/tauri';

export function OnboardingWizard({ status }: { status: OnboardingStatus }) {
  const { t } = useTranslation();

  return (
    <section className="onboarding-card">
      <h2>{t('app.onboardingTitle')}</h2>
      <p>{status.has_rclone ? t('app.rcloneDetected') : t('app.rcloneMissing')}</p>
      <p className="onboarding-card__source">Source: {status.source}</p>
      {!status.has_rclone ? <code>{status.brew_install_command}</code> : null}
      <code>{status.remote_create_command}</code>
    </section>
  );
}
