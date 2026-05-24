import { render, screen } from '@testing-library/react';

import '../lib/i18n';
import { PairDetailView } from './PairDetailView';

test('renders alarm banner when pair severity is Alarm', () => {
  render(
    <PairDetailView
      pair={{
        id: 1,
        name: 'Work Docs',
        remote_path: 'yd:/Work Docs',
        local_relative_path: 'Work Docs',
        severity: 'Alarm',
        schedule_minutes: 30,
      }}
    />
  );

  expect(screen.getByText('Push заблокирован')).toBeTruthy();
});

test('keeps manual pull action visible in alarm state', () => {
  render(
    <PairDetailView
      pair={{
        id: 1,
        name: 'Work Docs',
        remote_path: 'yd:/Work Docs',
        local_relative_path: 'Work Docs',
        severity: 'Alarm',
        schedule_minutes: 30,
      }}
    />
  );

  expect(screen.getByText(/загрузить из яндекса/i)).toBeTruthy();
});
