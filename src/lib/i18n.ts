import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';

import en from '../locales/en/app.json';
import ru from '../locales/ru/app.json';

void i18n.use(initReactI18next).init({
  resources: {
    en: { translation: en },
    ru: { translation: ru },
  },
  lng: 'ru',
  fallbackLng: 'ru',
  supportedLngs: ['ru', 'en'],
  interpolation: { escapeValue: false },
});

export default i18n;
