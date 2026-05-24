import { create } from 'zustand';

import { getAppOverview } from '../api/tauri';
import type { AppOverview } from '../types/contracts';

interface AppStore {
  overview: AppOverview | null;
  loadOverview: () => Promise<void>;
}

export const useAppStore = create<AppStore>((set) => ({
  overview: null,
  loadOverview: async () => {
    const overview = await getAppOverview();
    set({ overview });
  },
}));
