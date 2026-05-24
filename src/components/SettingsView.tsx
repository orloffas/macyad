import { disable, enable, isEnabled } from '@tauri-apps/plugin-autostart';
import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';

export function SettingsView(props: {
  language: 'ru' | 'en';
  onLanguageChange: (lang: 'ru' | 'en') => void;
}) {
  const { t } = useTranslation();
  const [autostartEnabled, setAutostartEnabled] = useState(false);

  useEffect(() => {
    void isEnabled().then(setAutostartEnabled).catch(() => {
      setAutostartEnabled(false);
    });
  }, []);

  return (
    <section className="settings-view">
      <h2>{t('app.settingsTitle')}</h2>
      <div className="settings-view__actions">
        <button
          aria-pressed={props.language === 'ru'}
          onClick={() => props.onLanguageChange('ru')}
        >
          {t('app.languageRu')}
        </button>
        <button
          aria-pressed={props.language === 'en'}
          onClick={() => props.onLanguageChange('en')}
        >
          {t('app.languageEn')}
        </button>
        <button
          onClick={() => {
            void (autostartEnabled ? disable() : enable())
              .then(() => setAutostartEnabled((current) => !current))
              .catch(() => undefined);
          }}
        >
          {autostartEnabled
            ? t('app.startAtLoginDisable')
            : t('app.startAtLoginEnable')}
        </button>
      </div>
    </section>
  );
}
