import { useEffect, useState } from 'react';
import type { Tweaks } from './types';
import { Climber } from './Climber';

interface CampScreenProps {
  tweaks: Tweaks;
  onBack: () => void;
}

export function CampScreen({ tweaks, onBack }: CampScreenProps) {
  const BREAK_SEC = 5 * 60;
  const [secsLeft, setSecsLeft] = useState(BREAK_SEC);
  const [running] = useState(true);

  useEffect(() => {
    if (!running) return;
    const id = window.setInterval(() => {
      setSecsLeft(s => Math.max(0, s - 1));
    }, 1000);
    return () => window.clearInterval(id);
  }, [running]);

  const mins = Math.floor(secsLeft / 60);
  const secs = secsLeft % 60;
  const accent = '#E85D3C';

  return (
    <div style={{
      width: '100%', height: '100%',
      background: 'linear-gradient(180deg, #1B1F36 0%, #2A2440 50%, #3A2A38 100%)',
      position: 'relative', overflow: 'hidden',
      color: '#F4ECDC',
      display: 'flex', flexDirection: 'column',
    }}>
      <svg viewBox="0 0 100 100" preserveAspectRatio="none" style={{
        position: 'absolute', inset: 0, width: '100%', height: '100%',
      }}>
        <circle cx="78" cy="18" r="5" fill="#F0E5C4"/>
        <circle cx="76" cy="16.5" r="5" fill="#1B1F36"/>
        {([[8,10,0.3],[15,6,0.4],[22,14,0.3],[30,8,0.5],[44,12,0.3],[55,5,0.4],[62,16,0.3],[88,10,0.4],[92,22,0.3],[12,28,0.3],[40,30,0.3],[68,28,0.3]] as const).map(([x,y,r],i) => (
          <circle key={i} cx={x} cy={y} r={r} fill="#F4ECDC" opacity={0.6 + ((i * 73) % 41) / 100}>
            <animate attributeName="opacity" values="0.4;1;0.4" dur={`${2+i*0.3}s`} repeatCount="indefinite"/>
          </circle>
        ))}

        <path d="M 0 70 Q 12 55 25 60 Q 38 48 50 55 Q 62 42 75 52 Q 88 48 100 60 L 100 75 L 0 75 Z"
              fill="#0F1124" opacity="0.85"/>
        <path d="M 0 75 Q 18 65 35 70 Q 50 60 65 70 Q 82 65 100 72 L 100 80 L 0 80 Z"
              fill="#080A18"/>

        <rect x="0" y="78" width="100" height="22" fill="#1A1426"/>

        <g transform="translate(28 64)">
          <path d="M 0 14 L 12 0 L 24 14 Z" fill="#C84B2D"/>
          <path d="M 0 14 L 12 0 L 12 14 Z" fill="#A03821"/>
          <path d="M 9 14 L 12 5 L 15 14 Z" fill="#F4D27A" opacity="0.95"/>
          <path d="M 9 14 L 12 5 L 12 14 Z" fill="#E8B85A"/>
          <line x1="0" y1="14" x2="-4" y2="16" stroke="#666" strokeWidth="0.2"/>
          <line x1="24" y1="14" x2="28" y2="16" stroke="#666" strokeWidth="0.2"/>
        </g>

        <g transform="translate(60 76)">
          <rect x="-4" y="2" width="8" height="1.2" rx="0.4" fill="#3D2817" transform="rotate(15)"/>
          <rect x="-4" y="2" width="8" height="1.2" rx="0.4" fill="#3D2817" transform="rotate(-15)"/>
          <path d="M 0 2 Q -2.2 -1 -1 -3 Q 0 -2 0.5 -3.5 Q 1.5 -2 2.2 -3 Q 2.5 -1 0 2 Z" fill="#F2A03C">
            <animate attributeName="d"
              values="M 0 2 Q -2.2 -1 -1 -3 Q 0 -2 0.5 -3.5 Q 1.5 -2 2.2 -3 Q 2.5 -1 0 2 Z;
                      M 0 2 Q -2 -0.5 -1.2 -2.5 Q -0.3 -1.5 0.7 -3.8 Q 1.2 -1.8 2.5 -2.5 Q 2.2 -0.5 0 2 Z;
                      M 0 2 Q -2.2 -1 -1 -3 Q 0 -2 0.5 -3.5 Q 1.5 -2 2.2 -3 Q 2.5 -1 0 2 Z"
              dur="0.8s" repeatCount="indefinite"/>
          </path>
          <path d="M 0 1.5 Q -1.2 0 -0.5 -1.5 Q 0 -0.8 0.5 -2 Q 1 -0.5 0 1.5 Z" fill="#F2D544">
            <animate attributeName="opacity" values="1;0.7;1" dur="0.5s" repeatCount="indefinite"/>
          </path>
          <circle cx="0" cy="0" r="6" fill="#F2A03C" opacity="0.15"/>
          <circle cx="0" cy="0" r="10" fill="#F2A03C" opacity="0.05"/>
        </g>
      </svg>

      <div style={{
        position: 'absolute', left: '52%', top: '60%', zIndex: 2,
        transform: 'scale(1.5)',
      }}>
        <Climber size={48} mode="rest" variant={tweaks.climberType} accent={accent}/>
      </div>

      <div style={{ paddingTop: 60, padding: '60px 20px 0', position: 'relative', zIndex: 3 }}>
        <div style={{
          fontFamily: 'ui-monospace, "SF Mono", monospace',
          fontSize: 10, letterSpacing: 1.6,
          opacity: 0.5, textTransform: 'uppercase',
        }}>
          ⛺  Camp III · 6,200 m
        </div>
        <div style={{
          fontFamily: 'Georgia, "Iowan Old Style", serif',
          fontSize: 32, fontWeight: 400, letterSpacing: -0.5,
          marginTop: 6, lineHeight: 1.1,
        }}>
          Set up camp.<br/>
          <span style={{ fontStyle: 'italic', opacity: 0.7 }}>Catch your breath.</span>
        </div>
      </div>

      <div style={{
        marginTop: 'auto',
        padding: '20px 24px 50px',
        position: 'relative', zIndex: 3,
        display: 'flex', flexDirection: 'column', gap: 14,
      }}>
        <div style={{
          textAlign: 'center',
          fontFamily: 'ui-monospace, monospace',
          fontSize: 12, letterSpacing: 1.2,
          opacity: 0.6, textTransform: 'uppercase',
        }}>
          Break · {String(mins).padStart(2,'0')}:{String(secs).padStart(2,'0')} remaining
        </div>

        <div style={{
          background: 'rgba(244,236,220,0.08)',
          border: '0.5px solid rgba(244,236,220,0.15)',
          borderRadius: 18,
          padding: '14px 18px',
          backdropFilter: 'blur(20px)',
          WebkitBackdropFilter: 'blur(20px)',
          display: 'flex', alignItems: 'center', gap: 14,
        }}>
          <div style={{ fontSize: 24 }}>☕</div>
          <div style={{ flex: 1 }}>
            <div style={{
              fontFamily: '-apple-system, system-ui', fontSize: 15, fontWeight: 600,
            }}>Brew tea, breathe deeply</div>
            <div style={{
              fontFamily: '-apple-system, system-ui', fontSize: 12, opacity: 0.6,
              textWrap: 'pretty',
            }}>
              Slow, even breaths. Hydrate. The summit is closer than you think.
            </div>
          </div>
        </div>

        <button onClick={onBack} style={{
          height: 50,
          borderRadius: 999,
          background: 'rgba(244,236,220,0.95)',
          color: '#1B1F36',
          border: 'none',
          fontFamily: '-apple-system, system-ui',
          fontSize: 15, fontWeight: 600,
          letterSpacing: 0.2,
          cursor: 'pointer',
        }}>
          ▲  Pack up & continue climbing
        </button>
      </div>
    </div>
  );
}
