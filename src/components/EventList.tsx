import { useTranslation } from 'react-i18next';

export function EventList({ items }: { items: string[] }) {
  const { t } = useTranslation();

  return (
    <section className="event-list">
      <h2>{t('app.recentEvents')}</h2>
      <ul>
        {items.map((item) => (
          <li key={item}>{item}</li>
        ))}
      </ul>
    </section>
  );
}
