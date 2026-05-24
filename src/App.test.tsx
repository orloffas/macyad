import { vi } from 'vitest';
import { render, screen } from '@testing-library/react';

import './lib/i18n';
import App from './App';

vi.mock('./api/tauri', () => ({
  getOnboardingStatus: async () => ({
    has_rclone: false,
    source: 'missing',
    brew_install_command: 'brew install rclone',
    remote_create_command: 'rclone --config ...',
  }),
}));

vi.mock('./state/app-store', () => ({
  useAppStore: (selector: (state: {
    overview: {
      ui_language: string;
      has_rclone: boolean;
      next_push_in_minutes: number | null;
      pairs: [];
    };
    loadOverview: () => Promise<void>;
  }) => unknown) =>
    selector({
      overview: {
        ui_language: 'ru',
        has_rclone: true,
        next_push_in_minutes: 30,
        pairs: [],
      },
      loadOverview: async () => {},
    }),
}));

test('renders localized shell from overview state', async () => {
  render(<App />);

  expect(await screen.findByText('Macyad')).toBeTruthy();
  expect(await screen.findByText('Rclone готов')).toBeTruthy();
});
