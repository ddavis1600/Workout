import { useCallback, useState } from 'react';
import type { Tweaks } from '../components/pomodoro/types';

const STORAGE_KEY = 'pomodoroMountain.tweaks';

const DEFAULTS: Tweaks = {
  artStyle: 'realistic',
  climberType: 'dog',
  timeOfDay: 'dawn',
  papercutVariant: 'epic',
  realisticVariant: 'painted',
};

function load(): Tweaks {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return DEFAULTS;
    return { ...DEFAULTS, ...JSON.parse(raw) };
  } catch {
    return DEFAULTS;
  }
}

export function usePomodoroSettings(): [Tweaks, <K extends keyof Tweaks>(key: K, value: Tweaks[K]) => void] {
  const [tweaks, setTweaks] = useState<Tweaks>(load);

  const setTweak = useCallback(<K extends keyof Tweaks>(key: K, value: Tweaks[K]) => {
    setTweaks(prev => {
      const next = { ...prev, [key]: value };
      try {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
      } catch {
        // ignore quota errors
      }
      return next;
    });
  }, []);

  return [tweaks, setTweak];
}
