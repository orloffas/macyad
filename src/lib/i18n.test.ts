import i18n from './i18n';

test('falls back to ru for unknown locales', async () => {
  await i18n.changeLanguage('fr');

  expect(i18n.t('app.title')).toBe('Macyad');
  expect(i18n.resolvedLanguage).toBe('ru');
});
