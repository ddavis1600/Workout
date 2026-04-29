import { useEffect, useRef, useState } from 'react';
import type { Tweaks } from './types';

interface RadioOption<V extends string> {
  value: V;
  label: string;
}

interface SettingsPopoverProps {
  tweaks: Tweaks;
  setTweak: <K extends keyof Tweaks>(key: K, value: Tweaks[K]) => void;
  fg: string;
}

export function SettingsPopover({ tweaks, setTweak, fg }: SettingsPopoverProps) {
  const [open, setOpen] = useState(false);
  const popRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    function handler(e: MouseEvent) {
      if (popRef.current && !popRef.current.contains(e.target as Node)) {
        setOpen(false);
      }
    }
    window.addEventListener('mousedown', handler);
    return () => window.removeEventListener('mousedown', handler);
  }, [open]);

  return (
    <div ref={popRef} style={{ position: 'absolute', top: 64, left: 16, zIndex: 6 }}>
      <button
        type="button"
        onClick={() => setOpen(o => !o)}
        aria-label="Settings"
        style={{
          background: 'rgba(0,0,0,0.04)',
          border: `0.5px solid ${fg}33`,
          borderRadius: 999,
          padding: '6px 12px',
          cursor: 'pointer',
          fontFamily: 'ui-monospace, "SF Mono", monospace',
          fontSize: 10,
          letterSpacing: 1,
          color: fg,
          textTransform: 'uppercase',
        }}
      >
        ⚙ Style
      </button>

      {open && (
        <div style={{
          position: 'absolute',
          top: 36,
          left: 0,
          width: 220,
          background: 'rgba(244,236,220,0.97)',
          color: '#1A1A1A',
          border: '0.5px solid rgba(0,0,0,0.12)',
          borderRadius: 14,
          padding: '14px 14px 10px',
          boxShadow: '0 12px 36px rgba(0,0,0,0.18)',
          backdropFilter: 'blur(20px)',
          WebkitBackdropFilter: 'blur(20px)',
          fontFamily: '-apple-system, system-ui',
          maxHeight: 'calc(100vh - 160px)',
          overflowY: 'auto',
        }}>
          <Section title="Mountain art">
            <Radio
              label="Style"
              value={tweaks.artStyle}
              onChange={v => setTweak('artStyle', v)}
              options={[
                { value: 'realistic', label: 'Realistic' },
                { value: 'topo', label: 'Topo' },
                { value: 'papercut', label: 'Alto' },
                { value: 'pixel', label: 'Pixel' },
              ]}
            />
            {tweaks.artStyle === 'realistic' && (
              <Radio
                label="Realistic"
                value={tweaks.realisticVariant}
                onChange={v => setTweak('realisticVariant', v)}
                options={[
                  { value: 'photo', label: 'Photo' },
                  { value: 'painted', label: 'Painted' },
                  { value: 'cinematic', label: 'Cinema' },
                ]}
              />
            )}
            {tweaks.artStyle === 'papercut' && (
              <Radio
                label="Alto variant"
                value={tweaks.papercutVariant}
                onChange={v => setTweak('papercutVariant', v)}
                options={[
                  { value: 'classic', label: 'Classic' },
                  { value: 'serene', label: 'Serene' },
                  { value: 'epic', label: 'Epic' },
                ]}
              />
            )}
            <Radio
              label="Time of day"
              value={tweaks.timeOfDay}
              onChange={v => setTweak('timeOfDay', v)}
              options={[
                { value: 'dawn', label: 'Dawn' },
                { value: 'day', label: 'Day' },
                { value: 'dusk', label: 'Dusk' },
                { value: 'night', label: 'Night' },
              ]}
            />
          </Section>
          <Section title="Climber">
            <Radio
              label="Party"
              value={tweaks.climberType}
              onChange={v => setTweak('climberType', v)}
              options={[
                { value: 'solo', label: 'Solo' },
                { value: 'dog', label: '+ Dog' },
                { value: 'rope', label: 'Rope team' },
              ]}
            />
          </Section>
        </div>
      )}
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div style={{ marginBottom: 10 }}>
      <div style={{
        fontFamily: 'ui-monospace, "SF Mono", monospace',
        fontSize: 9,
        letterSpacing: 1.4,
        textTransform: 'uppercase',
        opacity: 0.55,
        marginBottom: 6,
      }}>
        {title}
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
        {children}
      </div>
    </div>
  );
}

function Radio<V extends string>({
  label,
  value,
  onChange,
  options,
}: {
  label: string;
  value: V;
  onChange: (v: V) => void;
  options: RadioOption<V>[];
}) {
  return (
    <div>
      <div style={{ fontSize: 10, opacity: 0.55, marginBottom: 4 }}>{label}</div>
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 4 }}>
        {options.map(o => {
          const active = o.value === value;
          return (
            <button
              key={o.value}
              type="button"
              onClick={() => onChange(o.value)}
              style={{
                fontSize: 11,
                padding: '4px 9px',
                borderRadius: 999,
                border: '0.5px solid rgba(0,0,0,0.18)',
                background: active ? '#1A1A1A' : 'transparent',
                color: active ? '#F4ECDC' : '#1A1A1A',
                cursor: 'pointer',
                fontFamily: '-apple-system, system-ui',
              }}
            >
              {o.label}
            </button>
          );
        })}
      </div>
    </div>
  );
}
