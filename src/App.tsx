import { useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';

import {
  createSyncPair,
  getOnboardingStatus,
  runCheckYandex,
  runPullFromYandex,
  runSyncNow,
  setUiLanguage,
  type OnboardingStatus,
} from './api/tauri';
import { EventList } from './components/EventList';
import { OnboardingWizard } from './components/OnboardingWizard';
import { PairDetailView } from './components/PairDetailView';
import { QuickActions } from './components/QuickActions';
import { SettingsView } from './components/SettingsView';
import { StatusHeader } from './components/StatusHeader';
import { SyncPairCard } from './components/SyncPairCard';
import { useAppStore } from './state/app-store';

export default function App() {
  const { t, i18n } = useTranslation();
  const [view, setView] = useState<
    'dashboard' | 'onboarding' | 'settings' | 'pair-detail'
  >('dashboard');
  const [status, setStatus] = useState<OnboardingStatus | null>(null);
  const [selectedPairId, setSelectedPairId] = useState<number | null>(null);
  const overview = useAppStore((state) => state.overview);
  const loadOverview = useAppStore((state) => state.loadOverview);
  const [draft, setDraft] = useState({
    name: 'Work Docs',
    local_relative_path: 'Work Docs',
    remote_path: 'yd:/Work Docs',
    schedule_minutes: 30,
    delete_policy: 'MirrorToYandex',
  });

  useEffect(() => {
    void loadOverview();
  }, [loadOverview]);

  useEffect(() => {
    void getOnboardingStatus().then(setStatus);
  }, []);

  useEffect(() => {
    if (overview?.ui_language) {
      void i18n.changeLanguage(overview.ui_language);
    }
  }, [i18n, overview?.ui_language]);

  useEffect(() => {
    if (!overview?.pairs.length) {
      setSelectedPairId(null);
      return;
    }

    if (selectedPairId && overview.pairs.some((pair) => pair.id === selectedPairId)) {
      return;
    }

    setSelectedPairId(overview.pairs[0].id);
  }, [overview?.pairs, selectedPairId]);

  if (!overview || !status) {
    return <main className="app-shell">{t('app.loading')}</main>;
  }

  if (!overview.has_rclone) {
    return <OnboardingWizard status={status} />;
  }

  const currentLanguage = i18n.resolvedLanguage === 'en' ? 'en' : 'ru';
  const selectedPair =
    overview.pairs.find((pair) => pair.id === selectedPairId) ?? overview.pairs[0] ?? null;
  const runAndRefresh = async (action: () => Promise<void>) => {
    await action();
    await loadOverview();
  };

  return (
    <main className="dashboard">
      <nav className="view-switch">
        <button onClick={() => setView('dashboard')}>Dashboard</button>
        <button onClick={() => setView('onboarding')}>Onboarding</button>
        <button onClick={() => setView('settings')}>Settings</button>
        {selectedPair ? (
          <button onClick={() => setView('pair-detail')}>{t('app.openDetails')}</button>
        ) : null}
      </nav>

      {view === 'dashboard' ? (
        <>
          <StatusHeader
            title={t('app.title')}
            subtitle={
              overview.has_rclone
                ? t('app.rcloneReady')
                : t('app.rcloneNotConfiguredYet')
            }
          />

          <QuickActions
            onSyncNow={() => {
              if (selectedPair) {
                void runAndRefresh(() => runSyncNow(selectedPair.id));
              }
            }}
            onCheckYandex={() => {
              if (selectedPair) {
                void runAndRefresh(() => runCheckYandex(selectedPair.id));
              }
            }}
            onPullFromYandex={() => {
              if (selectedPair) {
                void runAndRefresh(() => runPullFromYandex(selectedPair.id));
              }
            }}
          />

          <section className="pair-grid">
            {overview.pairs.map((pair) => (
              <SyncPairCard
                key={pair.id}
                pair={pair}
                onOpen={(id) => {
                  setSelectedPairId(id);
                  setView('pair-detail');
                }}
              />
            ))}
          </section>

          <form
            className="create-pair-form"
            onSubmit={(event) => {
              event.preventDefault();
              void createSyncPair(draft).then(async (pairId) => {
                setSelectedPairId(pairId);
                await loadOverview();
              });
            }}
          >
            <input
              value={draft.name}
              onChange={(event) =>
                setDraft((current) => ({ ...current, name: event.target.value }))
              }
            />
            <input
              value={draft.local_relative_path}
              onChange={(event) =>
                setDraft((current) => ({
                  ...current,
                  local_relative_path: event.target.value,
                }))
              }
            />
            <input
              value={draft.remote_path}
              onChange={(event) =>
                setDraft((current) => ({ ...current, remote_path: event.target.value }))
              }
            />
            <button type="submit">{t('app.createPair')}</button>
          </form>

          <EventList items={[t('app.bootstrapComplete')]} />
        </>
      ) : null}

      {view === 'onboarding' ? <OnboardingWizard status={status} /> : null}

      {view === 'settings' ? (
        <SettingsView
          language={currentLanguage}
          onLanguageChange={(lang) => {
            void setUiLanguage(lang)
              .then(async () => {
                await i18n.changeLanguage(lang);
                await loadOverview();
              })
              .catch(() => undefined);
          }}
        />
      ) : null}

      {view === 'pair-detail' && selectedPair ? (
        <PairDetailView
          pair={selectedPair}
          onPullFromYandex={() => {
            void runAndRefresh(() => runPullFromYandex(selectedPair.id));
          }}
        />
      ) : null}
    </main>
  );
}
