import { useCallback, useState } from 'react';
import type { Peak } from '../components/pomodoro/types';

const STORAGE_KEY = 'pomodoroMountain.peaks';

const SEED_PEAKS: Peak[] = [
  { name: 'Mt. Tabei', elev: 2840, date: 'Apr 18', sessions: 4, climber: 'solo', style: 'topo' },
  { name: 'Aiguille du Plan', elev: 3673, date: 'Apr 19', sessions: 6, climber: 'dog', style: 'papercut' },
  { name: 'Pico de Orizaba', elev: 5636, date: 'Apr 22', sessions: 8, climber: 'rope', style: 'topo' },
  { name: 'Mt. Asgard', elev: 2015, date: 'Apr 23', sessions: 3, climber: 'solo', style: 'pixel' },
  { name: 'Cerro Torre', elev: 3128, date: 'Apr 24', sessions: 5, climber: 'dog', style: 'topo' },
  { name: 'Ama Dablam', elev: 6812, date: 'Apr 25', sessions: 7, climber: 'rope', style: 'papercut' },
];

function load(): Peak[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return SEED_PEAKS;
    return JSON.parse(raw) as Peak[];
  } catch {
    return SEED_PEAKS;
  }
}

export function usePeaks(): [Peak[], (peak: Peak) => void] {
  const [peaks, setPeaks] = useState<Peak[]>(load);

  const addPeak = useCallback((peak: Peak) => {
    setPeaks(prev => {
      const next = [...prev, peak];
      try {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
      } catch {
        // ignore
      }
      return next;
    });
  }, []);

  return [peaks, addPeak];
}
