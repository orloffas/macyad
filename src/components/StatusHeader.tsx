export function StatusHeader({
  title,
  subtitle,
}: {
  title: string;
  subtitle: string;
}) {
  return (
    <header className="status-header">
      <p className="status-header__eyebrow">Menu bar control</p>
      <h1>{title}</h1>
      <p>{subtitle}</p>
    </header>
  );
}
