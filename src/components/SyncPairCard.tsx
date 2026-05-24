import { useTranslation } from 'react-i18next';

import type { SyncPairSummaryDto } from '../types/contracts';

export function SyncPairCard({
  pair,
  onOpen,
}: {
  pair: SyncPairSummaryDto;
  onOpen: (id: number) => void;
}) {
  const { t } = useTranslation();

  return (
    <article className={`pair-card pair-card--${pair.severity.toLowerCase()}`}>
      <div className="pair-card__header">
        <div>
          <strong>{pair.name}</strong>
          <p>{pair.local_relative_path}</p>
        </div>
        <span className="pair-card__severity">{pair.severity}</span>
      </div>

      <dl className="pair-card__meta">
        <div>
          <dt>Remote</dt>
          <dd>{pair.remote_path}</dd>
        </div>
        <div>
          <dt>Schedule</dt>
          <dd>{pair.schedule_minutes} min</dd>
        </div>
      </dl>

      <button onClick={() => onOpen(pair.id)}>{t('app.openDetails')}</button>
    </article>
  );
}
