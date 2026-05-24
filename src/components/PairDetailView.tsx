import { useTranslation } from 'react-i18next';

import type { SyncPairSummaryDto } from '../types/contracts';

export function PairDetailView({
  pair,
  onPullFromYandex,
}: {
  pair: SyncPairSummaryDto;
  onPullFromYandex?: () => void;
}) {
  const { t } = useTranslation();

  return (
    <section className="pair-detail">
      {pair.severity === 'Alarm' ? (
        <div className="alarm-banner">{t('app.pushBlocked')}</div>
      ) : null}

      <h2>{pair.name}</h2>

      <dl className="pair-detail__meta">
        <div>
          <dt>Local</dt>
          <dd>{pair.local_relative_path}</dd>
        </div>
        <div>
          <dt>Remote</dt>
          <dd>{pair.remote_path}</dd>
        </div>
        <div>
          <dt>Severity</dt>
          <dd>{pair.severity}</dd>
        </div>
        <div>
          <dt>Schedule</dt>
          <dd>{pair.schedule_minutes} min</dd>
        </div>
      </dl>

      <button
        className="pair-detail__action"
        onClick={() => {
          onPullFromYandex?.();
        }}
      >
        {t('app.pullFromYandex')}
      </button>
    </section>
  );
}
