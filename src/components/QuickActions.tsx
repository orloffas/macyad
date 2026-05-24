import { useTranslation } from 'react-i18next';

export function QuickActions(props: {
  onSyncNow: () => void;
  onCheckYandex: () => void;
  onPullFromYandex: () => void;
}) {
  const { t } = useTranslation();

  return (
    <section className="quick-actions">
      <button onClick={props.onSyncNow}>{t('app.syncNow')}</button>
      <button onClick={props.onCheckYandex}>{t('app.checkYandex')}</button>
      <button onClick={props.onPullFromYandex}>{t('app.pullFromYandex')}</button>
    </section>
  );
}
