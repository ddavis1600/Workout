import type { ClimberVariant } from './types';
import './pomodoro.css';

export type ClimberMode = 'climb' | 'rest' | 'summit' | 'idle';

interface ClimberProps {
  size?: number;
  mode?: ClimberMode;
  variant?: ClimberVariant;
  accent?: string;
}

export function Climber({
  size = 64,
  mode = 'climb',
  variant = 'solo',
  accent = '#E85D3C',
}: ClimberProps) {
  const skin = '#F4C09B';
  const coat = accent;
  const pants = '#2B2B2B';
  const pack = '#1A1A1A';
  const helmet = '#F2D544';

  return (
    <div style={{ position: 'relative', width: size, height: size }}>
      <svg
        width={size}
        height={size}
        viewBox="0 0 64 64"
        style={{ overflow: 'visible' }}
      >
        <defs>
          <filter id="climberShadow" x="-20%" y="-20%" width="140%" height="140%">
            <feGaussianBlur in="SourceAlpha" stdDeviation="0.6" />
            <feOffset dx="0" dy="0.8" result="off" />
            <feComponentTransfer><feFuncA type="linear" slope="0.4"/></feComponentTransfer>
            <feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge>
          </filter>
        </defs>

        <g
          filter="url(#climberShadow)"
          style={{
            transformOrigin: '32px 50px',
            animation:
              mode === 'rest' ? 'climberBreathe 4s ease-in-out infinite' :
              mode === 'summit' ? 'climberCheer 1.6s ease-in-out infinite' :
              'climberBreathe 2.4s ease-in-out infinite',
          }}
        >
          {variant === 'rope' && (
            <path
              d="M 8 38 Q 18 36 26 36"
              stroke="#C97A2E"
              strokeWidth="1.4"
              fill="none"
              strokeLinecap="round"
            />
          )}

          <g style={{
            transformOrigin: '32px 36px',
            animation: 'climberSway 2.4s ease-in-out infinite',
          }}>
            <rect x="22" y="30" width="13" height="16" rx="3" fill={pack} />
            <rect x="22" y="33" width="13" height="1.2" fill="#000" opacity="0.4" />
            <rect x="32" y="32" width="2" height="11" rx="1" fill={accent} opacity="0.85" />
          </g>

          <g>
            <path
              d="M 30 44 Q 28 50 26 56"
              stroke={pants}
              strokeWidth="3.2"
              strokeLinecap="round"
              fill="none"
              style={{
                transformOrigin: '30px 44px',
                animation: mode === 'climb' ? 'legBack 2.4s ease-in-out infinite' : 'none',
              }}
            />
            <path
              d="M 33 44 Q 36 49 38 54"
              stroke={pants}
              strokeWidth="3.2"
              strokeLinecap="round"
              fill="none"
              style={{
                transformOrigin: '33px 44px',
                animation: mode === 'climb' ? 'legFront 2.4s ease-in-out infinite' : 'none',
              }}
            />
            <ellipse cx="25" cy="56.5" rx="2.6" ry="1.5" fill="#1a1a1a" />
            <ellipse cx="39" cy="54.5" rx="2.8" ry="1.6" fill="#1a1a1a" />
          </g>

          <path
            d="M 26 28 Q 25 38 28 44 L 37 44 Q 39 38 38 28 Z"
            fill={coat}
          />
          <path
            d="M 27 30 Q 26.5 38 28.5 43"
            stroke="#fff"
            strokeWidth="0.6"
            opacity="0.35"
            fill="none"
          />
          <rect x="26" y="40" width="12" height="1.6" fill="#000" opacity="0.5" />

          <g style={{
            transformOrigin: '28px 30px',
            animation:
              mode === 'climb' ? 'pickaxeSwing 2.4s ease-in-out infinite' :
              mode === 'summit' ? 'armWave 1.6s ease-in-out infinite' : 'none',
          }}>
            <path
              d="M 28 30 Q 22 26 18 22"
              stroke={coat}
              strokeWidth="3"
              strokeLinecap="round"
              fill="none"
            />
            <circle cx="18" cy="22" r="2.2" fill={pants} />
            {mode === 'climb' && (
              <g>
                <line x1="18" y1="22" x2="10" y2="14" stroke="#6B4423" strokeWidth="1.4" strokeLinecap="round" />
                <path d="M 8 12 L 14 12 L 12 16 Z" fill="#999" stroke="#444" strokeWidth="0.4"/>
              </g>
            )}
            {mode === 'rest' && (
              <g transform="translate(16 21)">
                <rect x="-2" y="-2" width="4" height="3.5" rx="0.5" fill="#fff" stroke="#444" strokeWidth="0.4"/>
                <path d="M 2 -1 Q 3.5 0 2 1.5" stroke="#444" strokeWidth="0.4" fill="none"/>
                <path d="M -0.5 -3 Q 0 -5 -0.5 -7" stroke="#fff" strokeWidth="0.6" fill="none" opacity="0.7"
                  style={{ animation: 'steamRise 2s ease-out infinite' }}/>
              </g>
            )}
          </g>

          <g style={{
            transformOrigin: '37px 30px',
            animation: mode === 'climb' ? 'armReach 2.4s ease-in-out infinite' : 'none',
          }}>
            <path
              d="M 37 30 Q 42 28 44 24"
              stroke={coat}
              strokeWidth="3"
              strokeLinecap="round"
              fill="none"
            />
            <circle cx="44" cy="24" r="2.2" fill={pants} />
          </g>

          <g style={{ transformOrigin: '32px 22px' }}>
            <circle cx="32" cy="22" r="5" fill={skin} />
            <path
              d="M 27 21 Q 27 16 32 16 Q 37 16 37 21 Z"
              fill={helmet}
            />
            <path d="M 27 20.8 L 37 20.8" stroke="#000" strokeWidth="0.4" opacity="0.5"/>
            <circle cx="32" cy="18.5" r="1" fill="#fff" opacity="0.9" />
            <ellipse cx="30" cy="22.5" rx="1.6" ry="1.2" fill="#1a1a1a"/>
            <ellipse cx="34" cy="22.5" rx="1.6" ry="1.2" fill="#1a1a1a"/>
            <line x1="31.5" y1="22.5" x2="32.5" y2="22.5" stroke="#1a1a1a" strokeWidth="0.6"/>
            <circle cx="29.5" cy="24" r="0.7" fill="#E89B8C" opacity="0.6"/>
            <circle cx="34.5" cy="24" r="0.7" fill="#E89B8C" opacity="0.6"/>
            <path d="M 30.5 25.4 Q 32 26.2 33.5 25.4" stroke="#3A2A22" strokeWidth="0.5" fill="none" strokeLinecap="round"/>
          </g>

          {variant === 'dog' && (
            <g style={{
              animation: mode === 'climb' ? 'dogTrot 2.4s ease-in-out infinite' : 'none',
              transformOrigin: '50px 52px',
            }}>
              <ellipse cx="50" cy="52" rx="5" ry="3" fill="#D4A574"/>
              <circle cx="55" cy="50" r="2.6" fill="#D4A574"/>
              <path d="M 55 47.5 L 56.5 46 L 56.8 49 Z" fill="#8B5A2B"/>
              <ellipse cx="56.8" cy="50.5" rx="1.2" ry="0.8" fill="#8B5A2B"/>
              <circle cx="57.4" cy="50.3" r="0.3" fill="#000"/>
              <circle cx="55.3" cy="49.5" r="0.3" fill="#000"/>
              <line x1="47" y1="54" x2="47" y2="57" stroke="#8B5A2B" strokeWidth="1.2" strokeLinecap="round"/>
              <line x1="50" y1="54.5" x2="50" y2="57" stroke="#8B5A2B" strokeWidth="1.2" strokeLinecap="round"/>
              <line x1="52.5" y1="54" x2="52.5" y2="57" stroke="#8B5A2B" strokeWidth="1.2" strokeLinecap="round"/>
              <path d="M 45 51 Q 42 49 43 47" stroke="#D4A574" strokeWidth="1.6" fill="none" strokeLinecap="round"
                style={{ animation: 'dogTailWag 0.6s ease-in-out infinite' }}/>
            </g>
          )}

          {variant === 'rope' && (
            <g opacity="0.85" transform="translate(-20 -2)" style={{
              animation: mode === 'climb' ? 'climberBreathe 2.4s ease-in-out infinite -0.3s' : 'none',
              transformOrigin: '8px 42px',
            }}>
              <rect x="5" y="32" width="6" height="10" rx="2" fill="#3A6EA5"/>
              <circle cx="8" cy="29" r="3" fill={skin}/>
              <path d="M 5.5 28 Q 5.5 25 8 25 Q 10.5 25 10.5 28 Z" fill="#F2D544"/>
              <ellipse cx="7" cy="29.5" rx="0.8" ry="0.6" fill="#1a1a1a"/>
              <ellipse cx="9" cy="29.5" rx="0.8" ry="0.6" fill="#1a1a1a"/>
              <path d="M 6 42 L 5 50" stroke="#2B2B2B" strokeWidth="2" strokeLinecap="round"/>
              <path d="M 10 42 L 11 50" stroke="#2B2B2B" strokeWidth="2" strokeLinecap="round"/>
              <ellipse cx="5" cy="50.5" rx="1.6" ry="1" fill="#1a1a1a"/>
              <ellipse cx="11" cy="50.5" rx="1.6" ry="1" fill="#1a1a1a"/>
            </g>
          )}
        </g>
      </svg>
    </div>
  );
}
