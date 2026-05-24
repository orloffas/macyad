import { vi } from 'vitest';
import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';

import './lib/i18n';
import App from './App';

const mockState = vi.hoisted(() => ({
  onboardingStatus: {
    has_rclone: false,
    source: 'missing',
    brew_install_command: 'brew install rclone',
    remote_create_command: 'rclone --config ...',
  },
  overview: {
    ui_language: 'ru',
    has_rclone: true,
    next_push_in_minutes: 30,
    pairs: [] as Array<{
      id: number;
      name: string;
      remote_path: string;
      local_relative_path: string;
      severity: 'Healthy' | 'Info' | 'Warning' | 'Alarm';
      schedule_minutes: number;
    }>,
  },
  loadOverview: vi.fn(async () => {}),
  setUiLanguage: vi.fn(async () => {}),
  runPullFromYandex: vi.fn(async () => {}),
  runCheckYandex: vi.fn(async () => {}),
  runSyncNow: vi.fn(async () => {}),
  createSyncPair: vi.fn(async () => 1),
}));

vi.mock('./api/tauri', () => ({
  getOnboardingStatus: async () => mockState.onboardingStatus,
  setUiLanguage: mockState.setUiLanguage,
  runPullFromYandex: mockState.runPullFromYandex,
  runCheckYandex: mockState.runCheckYandex,
  runSyncNow: mockState.runSyncNow,
  createSyncPair: mockState.createSyncPair,
}));

vi.mock('./state/app-store', () => ({
  useAppStore: (
    selector: (state: {
      overview: typeof mockState.overview;
      loadOverview: typeof mockState.loadOverview;
    }) => unknown,
  ) =>
    selector({
      overview: mockState.overview,
      loadOverview: mockState.loadOverview,
    }),
}));

beforeEach(() => {
  mockState.onboardingStatus = {
    has_rclone: false,
    source: 'missing',
    brew_install_command: 'brew install rclone',
    remote_create_command: 'rclone --config ...',
  };
  mockState.overview = {
    ui_language: 'ru',
    has_rclone: true,
    next_push_in_minutes: 30,
    pairs: [],
  };
  mockState.loadOverview.mockClear();
  mockState.setUiLanguage.mockClear();
  mockState.runPullFromYandex.mockClear();
  mockState.runCheckYandex.mockClear();
  mockState.runSyncNow.mockClear();
  mockState.createSyncPair.mockClear();
});

test('renders localized shell from overview state', async () => {
  render(<App />);

  expect(await screen.findByText('Macyad')).toBeTruthy();
  expect(await screen.findByText('Rclone готов')).toBeTruthy();
});

test('opens detail view and pulls the selected pair instead of the first one', async () => {
  mockState.overview = {
    ui_language: 'ru',
    has_rclone: true,
    next_push_in_minutes: 30,
    pairs: [
      {
        id: 1,
        name: 'Work Docs',
        remote_path: 'yd:/Work Docs',
        local_relative_path: 'Work Docs',
        severity: 'Healthy',
        schedule_minutes: 30,
      },
      {
        id: 2,
        name: 'Personal Docs',
        remote_path: 'yd:/Personal Docs',
        local_relative_path: 'Personal Docs',
        severity: 'Warning',
        schedule_minutes: 45,
      },
    ],
  };

  render(<App />);

  await waitFor(() => {
    expect(document.querySelectorAll('article.pair-card').length).toBe(2);
  });

  const cards = document.querySelectorAll('article.pair-card');
  const card = cards[1] as HTMLElement | undefined;
  expect(card).toBeTruthy();
  expect(within(card as HTMLElement).getAllByText('Personal Docs').length).toBeGreaterThan(0);
  fireEvent.click(within(card as HTMLElement).getByRole('button', { name: 'Открыть детали' }));

  expect(await screen.findByRole('heading', { name: 'Personal Docs' })).toBeTruthy();

  fireEvent.click(screen.getByRole('button', { name: 'Загрузить из Яндекса' }));
  await waitFor(() => {
    expect(mockState.runPullFromYandex).toHaveBeenCalledWith(2);
  });
});

test('persists the selected language through the backend command', async () => {
  render(<App />);

  fireEvent.click(await screen.findByRole('button', { name: 'Settings' }));
  fireEvent.click(await screen.findByRole('button', { name: 'English' }));

  await waitFor(() => {
    expect(mockState.setUiLanguage).toHaveBeenCalledWith('en');
  });
});
