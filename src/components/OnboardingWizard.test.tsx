import { render, screen } from '@testing-library/react';

import '../lib/i18n';
import { OnboardingWizard } from './OnboardingWizard';

test('shows brew install action when rclone is missing', () => {
  render(
    <OnboardingWizard
      status={{
        has_rclone: false,
        source: 'missing',
        brew_install_command: 'brew install rclone',
        remote_create_command: 'rclone --config ...',
      }}
    />
  );

  expect(screen.getByText('brew install rclone')).toBeTruthy();
});

test('shows manual remote create command and attach-existing path', () => {
  render(
    <OnboardingWizard
      status={{
        has_rclone: true,
        source: 'existing',
        brew_install_command: 'brew install rclone',
        remote_create_command: 'rclone --config ... config create yd-app yandex',
      }}
    />
  );

  expect(screen.getByText(/config create yd-app yandex/i)).toBeTruthy();
});
