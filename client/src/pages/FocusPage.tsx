import { useState } from 'react';
import { TimerScreen } from '../components/pomodoro/TimerScreen';
import { CampScreen } from '../components/pomodoro/CampScreen';
import { PeaksScreen } from '../components/pomodoro/PeaksScreen';
import { usePomodoroSettings } from '../hooks/usePomodoroSettings';

type Screen = 'timer' | 'camp' | 'peaks';

export default function FocusPage() {
  const [tweaks, setTweak] = usePomodoroSettings();
  const [screen, setScreen] = useState<Screen>('timer');

  return (
    <div style={{
      background: '#E8E2D2',
      minHeight: 'calc(100vh - 64px)',
      padding: 20,
      display: 'flex',
      justifyContent: 'center',
      alignItems: 'flex-start',
    }}>
      <div style={{
        width: '100%',
        maxWidth: 480,
        height: 'min(844px, calc(100vh - 100px))',
        background: '#F4ECDC',
        borderRadius: 24,
        overflow: 'hidden',
        boxShadow: '0 20px 60px rgba(0,0,0,0.18)',
        position: 'relative',
      }}>
        {screen === 'timer' && (
          <TimerScreen
            tweaks={tweaks}
            setTweak={setTweak}
            onBreak={() => setScreen('camp')}
            onPeaks={() => setScreen('peaks')}
          />
        )}
        {screen === 'camp' && (
          <CampScreen tweaks={tweaks} onBack={() => setScreen('timer')}/>
        )}
        {screen === 'peaks' && (
          <PeaksScreen onBack={() => setScreen('timer')}/>
        )}
      </div>
    </div>
  );
}
