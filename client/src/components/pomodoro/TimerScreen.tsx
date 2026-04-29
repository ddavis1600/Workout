import { useEffect, useMemo, useRef, useState } from 'react';
import type { Tweaks } from './types';
import { TopoMountain } from './Mountain';
import { Climber } from './Climber';
import { pointOnPath, CAMPS } from './mountainPath';
import { SettingsPopover } from './SettingsPopover';

interface TimerScreenProps {
  tweaks: Tweaks;
  setTweak: <K extends keyof Tweaks>(key: K, value: Tweaks[K]) => void;
  onBreak: () => void;
  onPeaks: () => void;
}

export function TimerScreen({ tweaks, setTweak, onBreak, onPeaks }: TimerScreenProps) {
  const SESSION_SEC = 25 * 60;
  const [secsLeft, setSecsLeft] = useState(SESSION_SEC);
  const [running, setRunning] = useState(false);
  const intervalRef = useRef<number | null>(null);

  useEffect(() => {
    if (running) {
      intervalRef.current = window.setInterval(() => {
        setSecsLeft(s => {
          if (s <= 1) {
            if (intervalRef.current) window.clearInterval(intervalRef.current);
            setRunning(false);
            return 0;
          }
          return s - 1;
        });
      }, 1000);
    }
    return () => {
      if (intervalRef.current) window.clearInterval(intervalRef.current);
    };
  }, [running]);

  const progress = 1 - secsLeft / SESSION_SEC;
  const mins = Math.floor(secsLeft / 60);
  const secs = secsLeft % 60;
  const climberPos = pointOnPath(progress);

  const encouragement = useMemo(() => {
    if (progress < 0.05) return 'Roping in at basecamp.';
    if (progress < 0.25) return 'Steady pace through the foothills.';
    if (progress < 0.5) return 'Past Camp I — strong start.';
    if (progress < 0.75) return 'Almost at the ridge!';
    if (progress < 0.95) return 'Final push to the summit.';
    return 'Summit reached. Breathe it in.';
  }, [progress]);

  const accent = '#E85D3C';
  const isNight = tweaks.timeOfDay === 'night';
  const fg = isNight ? '#F4ECDC' : '#1A1A1A';

  return (
    <div style={{
      position: 'relative',
      width: '100%', height: '100%',
      display: 'flex', flexDirection: 'column',
      background: isNight ? '#0F1424' : '#F4ECDC',
      color: fg,
    }}>
      <div style={{ position: 'relative', height: '58%', overflow: 'hidden' }}>
        <TopoMountain
          progress={progress}
          w="100%"
          h="100%"
          accent={accent}
          timeOfDay={tweaks.timeOfDay}
          style={tweaks.artStyle}
          papercutVariant={tweaks.papercutVariant}
          realisticVariant={tweaks.realisticVariant}
        />
        <div style={{
          position: 'absolute',
          left: `calc(${climberPos.x * 100}% - 22px)`,
          top: `calc(${climberPos.y * 100}% - 36px)`,
          transition: 'left 1s linear, top 1s linear',
          pointerEvents: 'none',
        }}>
          <Climber size={44} mode={progress >= 1 ? 'summit' : 'climb'} variant={tweaks.climberType} accent={accent}/>
        </div>

        <div style={{
          position: 'absolute', top: 70, left: 20,
          fontFamily: 'ui-monospace, "SF Mono", monospace',
          fontSize: 10, letterSpacing: 1.4,
          color: fg, opacity: 0.6, textTransform: 'uppercase',
        }}>
          Expedition · Session 03
        </div>

        <SettingsPopover tweaks={tweaks} setTweak={setTweak} fg={fg}/>

        <button onClick={onPeaks} style={{
          position: 'absolute', top: 64, right: 16, zIndex: 5,
          background: 'rgba(0,0,0,0.04)', border: `0.5px solid ${fg}33`,
          borderRadius: 999, padding: '6px 12px', cursor: 'pointer',
          fontFamily: 'ui-monospace, "SF Mono", monospace',
          fontSize: 10, letterSpacing: 1, color: fg, textTransform: 'uppercase',
        }}>
          ⌂ Peaks
        </button>
      </div>

      <div style={{
        flex: 1,
        padding: '24px 24px 50px',
        display: 'flex', flexDirection: 'column', gap: 18,
        background: isNight ? '#0F1424' : '#F4ECDC',
        borderTop: `0.5px dashed ${fg}22`,
      }}>
        <div style={{
          fontFamily: 'Georgia, "Iowan Old Style", serif',
          fontSize: 18,
          fontStyle: 'italic',
          color: fg,
          opacity: 0.85,
          textAlign: 'center',
          minHeight: 24,
          textWrap: 'pretty',
        }}>
          “{encouragement}”
        </div>

        <div style={{
          textAlign: 'center',
          fontFamily: 'ui-monospace, "SF Mono", "JetBrains Mono", monospace',
          fontSize: 76,
          fontWeight: 300,
          letterSpacing: -2,
          lineHeight: 1,
          color: fg,
          fontVariantNumeric: 'tabular-nums',
        }}>
          {String(mins).padStart(2, '0')}:{String(secs).padStart(2, '0')}
        </div>

        <div style={{ position: 'relative', padding: '0 4px' }}>
          <div style={{
            height: 2,
            background: `${fg}20`,
            borderRadius: 1,
            position: 'relative',
          }}>
            <div style={{
              position: 'absolute', left: 0, top: 0, height: '100%',
              width: `${progress * 100}%`,
              background: accent,
              borderRadius: 1,
              transition: 'width 1s linear',
            }}/>
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8 }}>
            {CAMPS.map((c, i) => {
              const reached = progress >= c.progress - 0.001;
              return (
                <div key={i} style={{
                  fontFamily: 'ui-monospace, monospace',
                  fontSize: 8.5, letterSpacing: 0.6,
                  color: fg,
                  opacity: reached ? 1 : 0.4,
                  textTransform: 'uppercase',
                  textAlign: i === 0 ? 'left' : i === CAMPS.length - 1 ? 'right' : 'center',
                  flex: 1,
                }}>
                  {c.label}
                </div>
              );
            })}
          </div>
        </div>

        <div style={{ display: 'flex', gap: 12, marginTop: 'auto', justifyContent: 'center', alignItems: 'center' }}>
          <button onClick={() => { setSecsLeft(SESSION_SEC); setRunning(false); }} style={iconBtnStyle(fg)}>
            ↺
          </button>
          <button onClick={() => setRunning(r => !r)} style={{
            ...primaryBtnStyle(accent),
            transform: running ? 'scale(0.96)' : 'scale(1)',
          }}>
            {running ? '❚❚ Pause climb' : (secsLeft === SESSION_SEC ? '▲ Begin climb' : '▲ Resume')}
          </button>
          <button onClick={onBreak} style={iconBtnStyle(fg)}>
            ⛺
          </button>
        </div>
      </div>
    </div>
  );
}

function iconBtnStyle(fg: string): React.CSSProperties {
  return {
    width: 44, height: 44, borderRadius: 999,
    background: 'transparent',
    border: `0.5px solid ${fg}40`,
    color: fg,
    fontSize: 18,
    cursor: 'pointer',
    display: 'flex', alignItems: 'center', justifyContent: 'center',
    fontFamily: '-apple-system, system-ui',
  };
}

function primaryBtnStyle(accent: string): React.CSSProperties {
  return {
    height: 52,
    padding: '0 28px',
    borderRadius: 999,
    background: accent,
    color: '#fff',
    border: 'none',
    fontFamily: '-apple-system, system-ui',
    fontSize: 16,
    fontWeight: 600,
    letterSpacing: 0.3,
    cursor: 'pointer',
    boxShadow: '0 4px 14px rgba(232,93,60,0.35), inset 0 1px 0 rgba(255,255,255,0.25)',
    transition: 'transform 0.15s ease',
  };
}
