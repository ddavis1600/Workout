import { useEffect, useRef, useState } from 'react';
import type { ArtStyle, TimeOfDay, PapercutVariant, RealisticVariant } from './types';
import { MOUNTAIN_PATH, pointOnPath, CAMPS } from './mountainPath';
import { PhotoRealistic, PaintedRealistic, CinematicRealistic } from './RealisticMountain';
import './pomodoro.css';

interface TopoMountainProps {
  progress?: number;
  w?: number | string;
  h?: number | string;
  accent?: string;
  timeOfDay?: TimeOfDay;
  style?: ArtStyle;
  papercutVariant?: PapercutVariant;
  realisticVariant?: RealisticVariant;
}

export function TopoMountain({
  progress = 0,
  w,
  h,
  accent = '#E85D3C',
  timeOfDay = 'dawn',
  style = 'topo',
  papercutVariant = 'classic',
  realisticVariant = 'photo',
}: TopoMountainProps) {
  const bg: [string, string] = {
    dawn:   ['#F4ECDC', '#EAD8C0'],
    day:    ['#F2EEE3', '#E5DDC9'],
    dusk:   ['#F0DCC4', '#E8B89A'],
    night:  ['#1F2438', '#0F1424'],
  }[timeOfDay] as [string, string];
  const inkColor = timeOfDay === 'night' ? '#E5C97A' : '#1A1A1A';
  const inkAlpha = timeOfDay === 'night' ? 0.4 : 0.85;

  return (
    <svg viewBox="0 0 100 100" width={w} height={h} preserveAspectRatio="xMidYMid slice"
         style={{ display: 'block' }}>
      <defs>
        <linearGradient id={`bg-${timeOfDay}`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor={bg[0]} />
          <stop offset="100%" stopColor={bg[1]} />
        </linearGradient>
        <filter id="paperTex" x="0" y="0" width="100%" height="100%">
          <feTurbulence baseFrequency="0.85" numOctaves="2" seed="4"/>
          <feColorMatrix values="0 0 0 0 0.9  0 0 0 0 0.85  0 0 0 0 0.7  0 0 0 0.06 0"/>
          <feComposite in2="SourceGraphic" operator="in"/>
        </filter>
      </defs>

      <rect x="0" y="0" width="100" height="100" fill={`url(#bg-${timeOfDay})`} />
      <rect x="0" y="0" width="100" height="100" filter="url(#paperTex)" opacity="0.5"/>

      {timeOfDay === 'night' && (
        <g fill="#fff" opacity="0.9">
          {([[10,15,0.4],[18,8,0.3],[28,18,0.5],[42,6,0.3],[58,12,0.4],[72,20,0.3],[88,8,0.5],[92,22,0.3],[8,28,0.3],[35,28,0.3]] as const)
            .map(([x,y,r], i) => <circle key={i} cx={x} cy={y} r={r}/>)}
          <circle cx="80" cy="20" r="3.5" fill="#F0E5C4"/>
          <circle cx="78.5" cy="18.8" r="3.5" fill={bg[0]}/>
        </g>
      )}

      {(timeOfDay === 'dawn' || timeOfDay === 'dusk') && (
        <circle cx="78" cy="22" r="6" fill={timeOfDay === 'dawn' ? '#F2C078' : '#E89B5C'} opacity="0.85"/>
      )}

      {style === 'topo' && (
        <TopoLines ink={inkColor} alpha={inkAlpha} />
      )}
      {style === 'papercut' && (
        <PaperCutLayers accent={accent} timeOfDay={timeOfDay} variant={papercutVariant}/>
      )}
      {style === 'pixel' && (
        <PixelMountain timeOfDay={timeOfDay}/>
      )}
      {style === 'realistic' && realisticVariant === 'photo' && (
        <PhotoRealistic timeOfDay={timeOfDay}/>
      )}
      {style === 'realistic' && realisticVariant === 'painted' && (
        <PaintedRealistic timeOfDay={timeOfDay}/>
      )}
      {style === 'realistic' && realisticVariant === 'cinematic' && (
        <CinematicRealistic timeOfDay={timeOfDay}/>
      )}

      <ClimberPath ink={inkColor} alpha={inkAlpha} progress={progress}/>

      {CAMPS.map((c, i) => {
        const pt = pointOnPath(c.progress);
        const reached = progress >= c.progress - 0.001;
        const isSummit = i === CAMPS.length - 1;
        return (
          <g key={i} transform={`translate(${pt.x * 100} ${pt.y * 100})`}>
            {isSummit ? (
              <g>
                <line x1="0" y1="0" x2="0" y2="-4" stroke={inkColor} strokeWidth="0.3"/>
                <path d="M 0 -4 L 3 -3.2 L 0 -2.4 Z" fill={reached ? accent : '#999'}
                  style={reached ? { animation: 'flagFlap 1.6s ease-in-out infinite', transformOrigin: '0 -4px' } : {}}/>
              </g>
            ) : (
              <g>
                <path
                  d="M -1.4 0 L 0 -1.6 L 1.4 0 Z"
                  fill={reached ? accent : 'none'}
                  stroke={inkColor}
                  strokeWidth="0.25"
                  opacity={inkAlpha}
                />
              </g>
            )}
            <circle cx="0" cy="0.4" r="0.3" fill={inkColor} opacity={inkAlpha * 0.6}/>
          </g>
        );
      })}
    </svg>
  );
}

function TopoLines({ ink, alpha }: { ink: string; alpha: number }) {
  const cx = 50, cy = 12;
  const silhouette = "M 0 100 L 0 78 Q 8 76 14 70 Q 22 66 28 58 Q 36 52 42 44 Q 48 36 50 12 Q 52 36 58 44 Q 64 52 72 58 Q 80 66 88 70 Q 94 76 100 78 L 100 100 Z";

  const rings: React.JSX.Element[] = [];
  for (let i = 1; i <= 14; i++) {
    const t = i / 14;
    const radiusX = 50 - t * 47;
    const radiusY = 38 - t * 33;
    const ringCy = cy + (1 - t) * 50;
    const points: string[] = [];
    const N = 32;
    for (let k = 0; k < N; k++) {
      const angle = (k / N) * Math.PI * 2;
      const wobble = 1 + Math.sin(angle * 3 + i * 0.7) * 0.08 + Math.sin(angle * 5 + i) * 0.04;
      const x = cx + Math.cos(angle) * radiusX * wobble;
      const y = ringCy + Math.sin(angle) * radiusY * wobble * 0.6;
      points.push(`${x.toFixed(1)},${y.toFixed(1)}`);
    }
    rings.push(<polygon key={i} points={points.join(' ')} fill="none" stroke={ink} strokeWidth={i === 14 ? 0.4 : 0.2} opacity={alpha * (0.3 + t * 0.5)}/>);
  }

  return (
    <g>
      <path d={silhouette} fill={ink} opacity={alpha * 0.06}/>
      {rings}
      <path d={silhouette} fill="none" stroke={ink} strokeWidth="0.5" opacity={alpha * 0.9}/>
      <path d="M 0 78 Q 6 70 12 72 Q 18 68 24 74 L 0 80 Z" fill="none" stroke={ink} strokeWidth="0.3" opacity={alpha * 0.5}/>
      <path d="M 76 78 Q 84 68 92 74 Q 96 72 100 76 L 100 80 Z" fill="none" stroke={ink} strokeWidth="0.3" opacity={alpha * 0.5}/>

      <g fontFamily="ui-monospace, monospace" fontSize="1.6" fill={ink} opacity={alpha * 0.55}>
        <text x="49" y="11" textAnchor="middle">8848</text>
        <text x="42" y="42" textAnchor="middle">6200</text>
        <text x="32" y="68" textAnchor="middle">4400</text>
        <text x="14" y="84" textAnchor="middle">2100</text>
      </g>

      <g fontFamily="ui-monospace, monospace" fontSize="1.4" fill={ink} opacity={alpha * 0.4}>
        <text x="2" y="3.5">27.9881°N</text>
        <text x="2" y="5.5">86.9250°E</text>
      </g>

      <g transform="translate(91 6)" stroke={ink} strokeWidth="0.2" opacity={alpha * 0.6}>
        <circle cx="0" cy="0" r="2.5" fill="none"/>
        <line x1="0" y1="-2.5" x2="0" y2="2.5"/>
        <line x1="-2.5" y1="0" x2="2.5" y2="0"/>
        <text y="-3" textAnchor="middle" fontSize="1.4" fontFamily="ui-monospace, monospace" stroke="none" fill={ink}>N</text>
      </g>
    </g>
  );
}

interface AltoPalette {
  sky: string[];
  layers: string[];
  sun: string;
  sunGlow: string;
}

function PaperCutLayers({ accent, timeOfDay, variant = 'classic' }: { accent: string; timeOfDay: TimeOfDay; variant?: PapercutVariant }) {
  const palettes: Record<PapercutVariant, Record<TimeOfDay, AltoPalette>> = {
    classic: {
      dawn:  { sky: ['#9C4A6E','#E87A5A','#F4A07A','#F5C9A0'], layers: ['#3D2540','#5A3550','#7B4863','#9F5C73','#C97A82'], sun: '#FBE3A8', sunGlow: '#F5A878' },
      day:   { sky: ['#F0E8D6','#D4E8F0','#A8D8E8'], layers: ['#2C4858','#3F6378','#5C8298','#84A8B8','#B5CFD8'], sun: '#FFF4D8', sunGlow: '#FFE090' },
      dusk:  { sky: ['#3D2A50','#A03868','#E8593C','#F4A85C'], layers: ['#1F1A35','#3A2848','#5C3858','#84486C','#B05874'], sun: '#FFD080', sunGlow: '#F08850' },
      night: { sky: ['#08111F','#0F1830','#1A2540'], layers: ['#020610','#0A1024','#141B38','#1F284C','#2C3760'], sun: '#F0E5C4', sunGlow: '#7088B0' },
    },
    serene: {
      dawn:  { sky: ['#E8B4A0','#F2D5B8','#F7E9D5','#FAF2E5'], layers: ['#7E5468','#9A6D7E','#B58898','#CCA3AF','#E0C0C5'], sun: '#FFF0D0', sunGlow: '#F8C898' },
      day:   { sky: ['#A0BFD0','#C0DAE5','#E0EEF2','#F0F5F0'], layers: ['#3F5868','#5B7A8A','#7A99A6','#9DB7BE','#C0D0D0'], sun: '#FFFFE8', sunGlow: '#E8EFE0' },
      dusk:  { sky: ['#5B3A6E','#9A5078','#D86E78','#F2A088'], layers: ['#2A1F40','#4D3358','#724C70','#9A6884','#BC8694'], sun: '#FFCC88', sunGlow: '#E87858' },
      night: { sky: ['#0B0F26','#161E3F','#243057'], layers: ['#04081A','#0E1432','#1B244A','#283058','#363E66'], sun: '#E8E0C0', sunGlow: '#5878A8' },
    },
    epic: {
      dawn:  { sky: ['#5C2845','#B8403C','#E8703A','#F0A055'], layers: ['#1A0C24','#2E1838','#48284C','#683C5E','#8C5470'], sun: '#FFD888', sunGlow: '#FF7048' },
      day:   { sky: ['#3068A0','#5890C0','#90B8D8','#D0E0E8'], layers: ['#0A1A2A','#1A2E48','#2E4868','#506888','#7888A0'], sun: '#FFFFFF', sunGlow: '#C8E0F0' },
      dusk:  { sky: ['#1A1838','#5A2858','#B8385C','#F25840'], layers: ['#0A0418','#1C0C2E','#341848','#502868','#704084'], sun: '#FF9858', sunGlow: '#E03848' },
      night: { sky: ['#020514','#080F28','#102048'], layers: ['#000208','#040818','#0A1230','#142048','#1E2C5C'], sun: '#E8F0FF', sunGlow: '#4868B0' },
    },
  };
  const set = palettes[variant][timeOfDay];
  const id = `alto-${variant}-${timeOfDay}`;

  let layerDefs: { d: string; fill: string }[];
  if (variant === 'serene') {
    layerDefs = [
      { d: "M 0 72 Q 18 66 36 70 Q 54 64 72 70 Q 86 66 100 70 L 100 100 L 0 100 Z", fill: set.layers[4] },
      { d: "M 0 80 Q 22 70 42 76 Q 60 66 78 74 Q 90 70 100 76 L 100 100 L 0 100 Z", fill: set.layers[3] },
      { d: "M 0 86 Q 18 72 38 80 Q 50 50 62 78 Q 78 70 100 82 L 100 100 L 0 100 Z", fill: set.layers[2] },
      { d: "M 0 92 Q 14 80 30 86 Q 46 70 50 30 Q 56 70 70 84 Q 86 78 100 88 L 100 100 L 0 100 Z", fill: set.layers[1] },
      { d: "M 0 100 L 0 96 Q 30 92 60 95 Q 84 92 100 96 L 100 100 Z", fill: set.layers[0] },
    ];
  } else if (variant === 'epic') {
    layerDefs = [
      { d: "M 0 65 L 4 60 L 9 64 L 14 56 L 20 62 L 26 54 L 32 60 L 38 50 L 46 58 L 54 50 L 62 58 L 68 54 L 76 60 L 84 56 L 92 62 L 100 58 L 100 100 L 0 100 Z", fill: set.layers[4] },
      { d: "M 0 75 L 8 60 L 14 70 L 22 50 L 30 64 L 40 46 L 50 60 L 60 44 L 70 58 L 80 48 L 90 62 L 100 56 L 100 100 L 0 100 Z", fill: set.layers[3] },
      { d: "M 0 85 L 8 72 L 18 80 L 28 56 L 38 70 L 50 24 L 62 70 L 72 56 L 84 78 L 94 64 L 100 76 L 100 100 L 0 100 Z", fill: set.layers[2] },
      { d: "M 0 95 L 10 84 L 18 92 L 28 76 L 36 84 L 44 60 L 50 8 L 56 60 L 62 78 L 72 64 L 82 86 L 92 76 L 100 88 L 100 100 L 0 100 Z", fill: set.layers[1] },
      { d: "M 0 100 L 0 97 L 14 93 L 32 96 L 56 92 L 78 95 L 100 92 L 100 100 Z", fill: set.layers[0] },
    ];
  } else {
    layerDefs = [
      { d: "M 0 70 L 6 64 L 11 67 L 16 60 L 22 65 L 28 58 L 34 63 L 40 55 L 46 62 L 52 56 L 58 63 L 64 58 L 70 64 L 76 57 L 82 62 L 88 56 L 94 63 L 100 60 L 100 100 L 0 100 Z", fill: set.layers[4] },
      { d: "M 0 78 L 8 68 L 15 74 L 24 60 L 32 70 L 42 54 L 50 64 L 58 50 L 68 62 L 76 54 L 86 66 L 94 58 L 100 68 L 100 100 L 0 100 Z", fill: set.layers[3] },
      { d: "M 0 84 L 10 70 L 18 78 L 28 56 L 38 72 L 50 38 L 62 70 L 72 54 L 82 76 L 92 64 L 100 76 L 100 100 L 0 100 Z", fill: set.layers[2] },
      { d: "M 0 92 L 12 82 L 22 88 L 34 70 L 44 80 L 50 12 L 56 78 L 66 68 L 78 84 L 88 76 L 100 86 L 100 100 L 0 100 Z", fill: set.layers[1] },
      { d: "M 0 100 L 0 96 L 18 90 L 36 94 L 60 88 L 80 92 L 100 89 L 100 100 Z", fill: set.layers[0] },
    ];
  }

  const sunConfig = variant === 'serene' ? { cx: 70, cy: 30, r: 28, coreR: 7 } :
                    variant === 'epic'   ? { cx: 76, cy: 24, r: 14, coreR: 3 } :
                                           { cx: 74, cy: 28, r: 18, coreR: 4 };

  const snowColor = timeOfDay === 'night' ? '#C8D0E8' : '#F5F0E2';

  return (
    <g>
      <defs>
        <linearGradient id={id} x1="0" y1="0" x2="0" y2="1">
          {set.sky.map((c, i) => (
            <stop key={i} offset={`${(i / (set.sky.length - 1)) * 100}%`} stopColor={c}/>
          ))}
        </linearGradient>
        <radialGradient id={`${id}-sun`} cx="50%" cy="50%" r="50%">
          <stop offset="0%" stopColor={set.sun} stopOpacity="1"/>
          <stop offset="60%" stopColor={set.sunGlow} stopOpacity="0.4"/>
          <stop offset="100%" stopColor={set.sunGlow} stopOpacity="0"/>
        </radialGradient>
      </defs>

      <rect x="0" y="0" width="100" height="100" fill={`url(#${id})`}/>

      <circle cx={sunConfig.cx} cy={sunConfig.cy} r={sunConfig.r} fill={`url(#${id}-sun)`}/>
      <circle cx={sunConfig.cx} cy={sunConfig.cy} r={sunConfig.coreR} fill={set.sun}
              opacity={timeOfDay === 'night' ? 0.85 : 0.95}/>

      {variant === 'epic' && timeOfDay === 'night' && (
        <g opacity="0.5">
          <path d="M 0 30 Q 30 22 50 28 Q 70 18 100 26" stroke="#5CE8A8" strokeWidth="1.2" fill="none" opacity="0.6"/>
          <path d="M 0 36 Q 30 32 50 36 Q 70 28 100 34" stroke="#7AC8F0" strokeWidth="0.8" fill="none" opacity="0.5"/>
          <path d="M 0 42 Q 30 40 50 44 Q 70 38 100 42" stroke="#A878E8" strokeWidth="0.6" fill="none" opacity="0.4"/>
        </g>
      )}

      {variant === 'serene' && (
        <rect x="0" y="55" width="100" height="20" fill={set.sky[set.sky.length - 1]} opacity="0.4"/>
      )}

      {timeOfDay !== 'night' && variant !== 'epic' && (
        <g fill={set.sky[set.sky.length - 1]} opacity={variant === 'serene' ? 0.6 : 0.35}>
          <ellipse cx="20" cy="22" rx="8" ry="1.2"/>
          <ellipse cx="50" cy="14" rx="6" ry="0.9"/>
          <ellipse cx="88" cy="18" rx="5" ry="0.8"/>
        </g>
      )}

      {timeOfDay === 'night' && (
        <g fill="#fff">
          {([[8,12,0.25],[18,8,0.3],[30,16,0.2],[42,10,0.3],[58,6,0.25],[64,18,0.2],[88,12,0.3],[94,22,0.2],[12,30,0.25],[36,28,0.2]] as const)
            .map(([x,y,r], i) => <circle key={i} cx={x} cy={y} r={r} opacity={0.5 + ((i * 73) % 51) / 100}/>)}
        </g>
      )}

      {layerDefs.map((l, i) => <path key={i} d={l.d} fill={l.fill}/>)}

      {variant === 'epic' ? (
        <g>
          <path d="M 46 22 L 50 8 L 54 22 L 53 24 L 52 22 L 51 25 L 50 22 L 49 25 L 48 22 L 47 24 Z" fill={snowColor}/>
          <path d="M 47 32 L 50 25 L 53 32 Z" fill={snowColor} opacity="0.8"/>
          <path d="M 48 42 L 50 36 L 52 42 Z" fill={snowColor} opacity="0.6"/>
        </g>
      ) : variant === 'serene' ? (
        <path d="M 48 36 L 50 30 L 52 36 Z" fill={snowColor} opacity="0.7"/>
      ) : (
        <g>
          <path d="M 47 16 L 50 12 L 53 16 L 52 18 L 51.5 17 L 50.5 18.5 L 49.5 17 L 48.5 18 Z" fill={snowColor}/>
          <path d="M 49 22 L 50 19 L 51.5 23 Z" fill={snowColor} opacity="0.7"/>
        </g>
      )}

      <path d={variant === 'epic' ? "M 50 8 L 52 24 L 51 24 Z" : variant === 'serene' ? "M 50 30 L 51 38 L 50.4 38 Z" : "M 50 12 L 52 18 L 51 18 Z"}
            fill={accent} opacity="0.25"/>
    </g>
  );
}

function PixelMountain({ timeOfDay }: { timeOfDay: TimeOfDay }) {
  const dark = timeOfDay === 'night';
  const cells: React.JSX.Element[] = [];
  const px = 100 / 32;
  const heights = [
    20, 19, 19, 18, 18, 17, 16, 15, 14, 14, 13, 12, 11, 10, 9, 8,
    9, 10, 11, 12, 13, 14, 14, 15, 16, 17, 18, 18, 19, 19, 20, 21,
  ];
  const baseColor = dark ? '#3A4666' : '#7A6849';
  const midColor = dark ? '#2B3553' : '#5C4E36';
  const darkColor = dark ? '#1E2640' : '#3D3322';
  const snowColor = dark ? '#C8CFE5' : '#F5F0E8';

  for (let x = 0; x < 32; x++) {
    const top = heights[x];
    for (let y = top; y < 32; y++) {
      const dy = y - top;
      let color: string;
      if (dy < 2) color = snowColor;
      else if (y < 18) color = baseColor;
      else if (y < 24) color = midColor;
      else color = darkColor;
      if ((x + y) % 5 === 0 && y > top + 3) color = darkColor;
      cells.push(<rect key={`${x}-${y}`} x={x * px} y={y * px} width={px + 0.1} height={px + 0.1} fill={color}/>);
    }
  }
  return <g>{cells}</g>;
}

function ClimberPath({ ink, alpha, progress }: { ink: string; alpha: number; progress: number }) {
  const d = MOUNTAIN_PATH.map((p, i) => i === 0 ? `M ${p.x*100} ${p.y*100}` : `L ${p.x*100} ${p.y*100}`).join(' ');

  return (
    <g>
      <path d={d} fill="none" stroke={ink} strokeWidth="0.3" strokeDasharray="0.8 1.2" opacity={alpha * 0.5} strokeLinecap="round"/>
      <ProgressPath d={d} progress={progress} ink={ink} alpha={alpha}/>
    </g>
  );
}

function ProgressPath({ d, progress, ink, alpha }: { d: string; progress: number; ink: string; alpha: number }) {
  const pathRef = useRef<SVGPathElement>(null);
  const [len, setLen] = useState(0);
  useEffect(() => {
    if (pathRef.current) setLen(pathRef.current.getTotalLength());
  }, [d]);
  return (
    <path
      ref={pathRef}
      d={d}
      fill="none"
      stroke={ink}
      strokeWidth="0.6"
      strokeLinecap="round"
      strokeDasharray={`${len * progress} ${len}`}
      opacity={alpha}
    />
  );
}
