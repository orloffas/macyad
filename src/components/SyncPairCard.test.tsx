import { render, screen } from '@testing-library/react';

import '../lib/i18n';
import { SyncPairCard } from './SyncPairCard';

test('renders warning badge for warning pair', () => {
  render(
    <SyncPairCard
      pair={{
        id: 1,
        name: 'Work Docs',
        remote_path: 'yd:/Work Docs',
        local_relative_path: 'Work Docs',
        severity: 'Warning',
        schedule_minutes: 30,
      }}
      onOpen={() => {}}
    />
  );

  expect(screen.getByText('Warning')).toBeTruthy();
});
