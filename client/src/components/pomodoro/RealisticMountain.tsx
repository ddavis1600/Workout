import type { TimeOfDay, RealisticVariant } from './types';

interface Palette {
  skyTop: string;
  skyMid: string;
  skyHorizon: string;
  sunPos: [number, number];
  sunColor: string;
  haze: string;
  rockBase: string;
  rockLit: string;
  rockShade: string;
  snowLit: string;
  snowShade: string;
  distance: string;
}

function ridgePath(seed: number, baseY: number, peakY: number, jagginess = 1, startX = 0, endX = 100): string {
  let s = seed;
  const rand = () => { s = (s * 9301 + 49297) % 233280; return s / 233280; };
  const N = 22;
  const points: string[] = [`${startX} 100`, `${startX} ${baseY + rand() * 4}`];
  const peakIdx = Math.floor(N * (0.4 + rand() * 0.2));
  for (let i = 1; i < N; i++) {
    const x = startX + (endX - startX) * (i / (N - 1));
    const distFromPeak = Math.abs(i - peakIdx) / N;
    const baseLerp = baseY * distFromPeak * 1.3 + peakY * (1 - distFromPeak * 1.3);
    const y = Math.max(peakY, baseLerp + (rand() - 0.4) * 8 * jagginess);
    points.push(`${x.toFixed(2)} ${y.toFixed(2)}`);
  }
  points.push(`${endX} ${baseY + rand() * 4}`, `${endX} 100`);
  return 'M ' + points.join(' L ') + ' Z';
}

function heroPeakGeometry() {
  const silhouette = [
    "M 0 100",
    "L 0 92 L 4 88 L 8 86 L 12 84",
    "L 16 78 L 20 76 L 23 72",
    "L 26 64 L 28 62 L 30 56",
    "L 33 48 L 35 46 L 37 38",
    "L 39 32 L 41 30 L 43 24",
    "L 46 18 L 48 14 L 50 10 L 52 8",
    "L 54 6",
    "L 56 9 L 57 13 L 58 17",
    "L 59 22 L 60 26 L 60.5 30",
    "L 60 33 L 59.5 35",
    "L 60.5 38 L 62 42 L 63.5 45",
    "L 65 49 L 67 51",
    "L 68 54 L 69 56",
    "L 70 58 L 71 59",
    "L 72 57 L 73 59 L 74 62",
    "L 75 66 L 77 68 L 79 71",
    "L 81 74 L 83 76 L 85 78",
    "L 88 81 L 91 83 L 94 85",
    "L 97 87 L 100 89",
    "L 100 100 Z",
  ].join(' ');

  const litSide = [
    "M 54 6",
    "L 56 9 L 57 13 L 58 17",
    "L 59 22 L 60 26 L 60.5 30",
    "L 60 33 L 59.5 35",
    "L 60.5 38 L 62 42 L 63.5 45",
    "L 65 49 L 67 51",
    "L 68 54 L 69 56",
    "L 70 58 L 71 59",
    "L 72 57 L 73 59 L 74 62",
    "L 75 66 L 77 68 L 79 71",
    "L 81 74 L 83 76 L 85 78",
    "L 88 81 L 91 83 L 94 85",
    "L 97 87 L 100 89",
    "L 100 100 L 54 100 Z",
  ].join(' ');

  const shadowSide = [
    "M 0 100",
    "L 0 92 L 4 88 L 8 86 L 12 84",
    "L 16 78 L 20 76 L 23 72",
    "L 26 64 L 28 62 L 30 56",
    "L 33 48 L 35 46 L 37 38",
    "L 39 32 L 41 30 L 43 24",
    "L 46 18 L 48 14 L 50 10 L 52 8",
    "L 54 6",
    "L 54 100 Z",
  ].join(' ');

  const ridgeLineEast = [
    "M 54 6",
    "L 56 9 L 57 13 L 58 17 L 59 22 L 60 26 L 60.5 30",
    "L 60.5 38 L 62 42 L 63.5 45 L 65 49 L 67 51",
    "L 68 54 L 69 56 L 70 58 L 71 59",
    "L 73 59 L 74 62 L 75 66 L 77 68 L 79 71 L 81 74 L 83 76 L 85 78 L 88 81 L 91 83",
  ].join(' ');
  const ridgeLineWest = "M 54 6 L 52 8 L 50 10 L 48 14 L 46 18 L 43 24 L 41 30 L 39 32 L 37 38 L 35 46 L 33 48 L 30 56 L 28 62 L 26 64 L 23 72 L 20 76";

  const snowMain = [
    "M 54 6",
    "L 56 10 L 57 15 L 58 19 L 58.5 24 L 59 28",
    "L 58.5 32 L 58 36",
    "L 57.5 40 L 56.5 36 L 56 30 L 55.5 24",
    "L 55 18 L 54.5 12",
    "L 53 16 L 52.5 22 L 52 28 L 51.5 34 L 51 40",
    "L 50.5 32 L 50 26 L 49.5 20 L 49 14 L 50 10 L 52 8 Z",
  ].join(' ');

  const couloirsShadow = [
    "M 49 16 L 49.5 22 L 49.7 30 L 49.9 38 L 49.7 48 L 49.4 54 L 49 48 L 48.7 38 L 48.5 28 L 48.3 22 Z",
    "M 44 28 L 44.4 34 L 44.6 42 L 44.5 50 L 44.2 56 L 43.9 50 L 43.7 42 L 43.4 36 L 43.5 30 Z",
    "M 38 38 L 38.3 44 L 38.5 50 L 38.4 56 L 38.1 60 L 37.8 56 L 37.6 50 L 37.5 44 Z",
    "M 31 56 L 31.2 60 L 31.3 64 L 31.0 68 L 30.7 64 L 30.6 60 Z",
  ];
  const couloirsLit = [
    "M 58 22 L 58.4 28 L 58.6 34 L 58.4 40 L 58 44 L 57.7 38 L 57.5 30 L 57.6 26 Z",
    "M 64 46 L 64.2 50 L 64.3 54 L 64 58 L 63.7 54 L 63.5 50 Z",
  ];

  return { silhouette, litSide, shadowSide, ridgeLineEast, ridgeLineWest, snowMain, couloirsShadow, couloirsLit };
}

interface BaseProps {
  palette: Palette;
  timeOfDay: TimeOfDay;
  variant: RealisticVariant;
  id: string;
}

function RealisticBase({ palette: p, timeOfDay, variant, id }: BaseProps) {
  const geo = heroPeakGeometry();
  const isNight = timeOfDay === 'night';

  const distantRange = ridgePath(7, 68, 56, 0.7);
  const midRange = ridgePath(13, 78, 64, 0.9);
  const closerRange = ridgePath(29, 84, 70, 1.0);

  return (
    <g>
      <defs>
        <linearGradient id={`${id}-sky`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor={p.skyTop}/>
          <stop offset="55%" stopColor={p.skyMid}/>
          <stop offset="100%" stopColor={p.skyHorizon}/>
        </linearGradient>
        <radialGradient id={`${id}-sun`} cx="50%" cy="50%" r="50%">
          <stop offset="0%" stopColor={p.sunColor} stopOpacity="1"/>
          <stop offset="35%" stopColor={p.sunColor} stopOpacity="0.5"/>
          <stop offset="100%" stopColor={p.sunColor} stopOpacity="0"/>
        </radialGradient>
        <linearGradient id={`${id}-peakLit`} x1="0" y1="0" x2="1" y2="0.5">
          <stop offset="0%" stopColor={p.rockShade}/>
          <stop offset="35%" stopColor={p.rockBase}/>
          <stop offset="100%" stopColor={p.rockLit}/>
        </linearGradient>
        <linearGradient id={`${id}-peakShadow`} x1="0" y1="0" x2="1" y2="0">
          <stop offset="0%" stopColor={p.rockShade} stopOpacity="0.95"/>
          <stop offset="100%" stopColor={p.rockBase} stopOpacity="0.85"/>
        </linearGradient>
        <linearGradient id={`${id}-haze`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor={p.haze} stopOpacity="0.85"/>
          <stop offset="100%" stopColor={p.haze} stopOpacity="0"/>
        </linearGradient>
        <linearGradient id={`${id}-snow`} x1="0" y1="0" x2="0.5" y2="0.7">
          <stop offset="0%" stopColor={p.snowLit}/>
          <stop offset="100%" stopColor={p.snowShade}/>
        </linearGradient>
        <linearGradient id={`${id}-alpenglow`} x1="0" y1="0" x2="1" y2="0.3">
          <stop offset="0%" stopColor={p.sunColor} stopOpacity="0"/>
          <stop offset="100%" stopColor={p.sunColor} stopOpacity={variant === 'cinematic' ? 0.7 : 0.3}/>
        </linearGradient>
        <linearGradient id={`${id}-godray`} x1="0.5" y1="0" x2="0.4" y2="1">
          <stop offset="0%" stopColor={p.sunColor} stopOpacity="0.5"/>
          <stop offset="100%" stopColor={p.sunColor} stopOpacity="0"/>
        </linearGradient>
        <filter id={`${id}-grain`} x="0" y="0" width="100%" height="100%">
          <feTurbulence baseFrequency="2.4" numOctaves="2" seed="11"/>
          <feColorMatrix values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 0.12 0"/>
          <feComposite in2="SourceGraphic" operator="in"/>
        </filter>
        <filter id={`${id}-brush`} x="0" y="0" width="100%" height="100%">
          <feTurbulence baseFrequency="0.8" numOctaves="3" seed="3"/>
          <feColorMatrix values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 0.18 0"/>
          <feComposite in2="SourceGraphic" operator="in"/>
        </filter>
        <radialGradient id={`${id}-vignette`} cx="50%" cy="50%" r="75%">
          <stop offset="60%" stopColor="#000" stopOpacity="0"/>
          <stop offset="100%" stopColor="#000" stopOpacity="0.45"/>
        </radialGradient>
        <clipPath id={`${id}-heroClip`}>
          <path d={geo.silhouette}/>
        </clipPath>
      </defs>

      <rect x="0" y="0" width="100" height="100" fill={`url(#${id}-sky)`}/>

      <circle cx={p.sunPos[0]} cy={p.sunPos[1]} r="28" fill={`url(#${id}-sun)`}/>
      <circle cx={p.sunPos[0]} cy={p.sunPos[1]} r={variant === 'cinematic' ? 2 : 3} fill={p.sunColor} opacity="0.95"/>

      {variant === 'cinematic' && !isNight && (
        <g opacity="0.5">
          <circle cx={p.sunPos[0] - 12} cy={p.sunPos[1] + 10} r="2.5" fill={p.sunColor} opacity="0.4"/>
          <circle cx={p.sunPos[0] - 24} cy={p.sunPos[1] + 18} r="1.4" fill={p.sunColor} opacity="0.3"/>
          <circle cx={p.sunPos[0] - 36} cy={p.sunPos[1] + 28} r="3" fill={p.sunColor} opacity="0.2"/>
        </g>
      )}

      {variant === 'painted' && !isNight && (
        <g opacity="0.4">
          <path d={`M ${p.sunPos[0]} ${p.sunPos[1]} L 30 100 L 50 100 Z`} fill={`url(#${id}-godray)`}/>
          <path d={`M ${p.sunPos[0]} ${p.sunPos[1]} L 60 100 L 80 100 Z`} fill={`url(#${id}-godray)`}/>
          <path d={`M ${p.sunPos[0]} ${p.sunPos[1]} L 0 100 L 20 100 Z`} fill={`url(#${id}-godray)`}/>
        </g>
      )}

      {isNight && (
        <g fill="#fff">
          {([[6,8,0.22],[14,4,0.3],[22,12,0.18],[34,6,0.25],[46,3,0.3],[58,9,0.2],[68,14,0.18],[88,5,0.28],[94,18,0.22],[10,24,0.2],[40,22,0.18],[68,2,0.22]] as const).map(([x,y,r],i) => (
            <circle key={i} cx={x} cy={y} r={r} opacity={0.4 + ((i * 73) % 51) / 100}/>
          ))}
        </g>
      )}

      {!isNight && variant !== 'cinematic' && (
        <g opacity={variant === 'painted' ? 0.55 : 0.4}>
          <ellipse cx="20" cy="20" rx="14" ry="1.4" fill={p.skyHorizon}/>
          <ellipse cx="46" cy="14" rx="10" ry="1.0" fill={p.skyHorizon}/>
          <ellipse cx="64" cy="24" rx="8" ry="1.2" fill={p.skyHorizon}/>
        </g>
      )}

      <path d={distantRange} fill={p.distance} opacity="0.55"/>
      <path d={distantRange} fill={`url(#${id}-haze)`}/>

      <path d={midRange} fill={p.distance} opacity="0.85"/>
      <g opacity="0.6" fill={p.snowShade}>
        <ellipse cx="32" cy="65" rx="2.5" ry="0.8"/>
        <ellipse cx="58" cy="63" rx="3" ry="0.9"/>
        <ellipse cx="78" cy="65" rx="2" ry="0.7"/>
      </g>

      <path d={closerRange} fill={p.rockBase} opacity="0.92"/>
      <g fill={p.snowShade} opacity="0.7">
        <path d="M 14 76 L 17 73 L 20 78 Z"/>
        <path d="M 38 70 L 42 67 L 45 71 Z"/>
        <path d="M 62 72 L 66 69 L 70 74 Z"/>
        <path d="M 84 74 L 87 71 L 90 76 Z"/>
      </g>

      <path d={geo.shadowSide} fill={`url(#${id}-peakShadow)`}/>
      <path d={geo.litSide} fill={`url(#${id}-peakLit)`}/>

      <g clipPath={`url(#${id}-heroClip)`} fill={p.rockShade}>
        <path d="M 47 18 L 47.8 26 L 48 36 L 47.5 48 L 46.8 60 L 46 70 L 45 78 L 44 70 L 44.5 56 L 45.5 42 L 46.2 30 Z" opacity="0.4"/>
        <path d="M 41 32 L 42 42 L 42.5 54 L 42 64 L 41.2 74 L 40 80 L 39.5 70 L 40 56 L 40.5 44 L 40.8 36 Z" opacity="0.35"/>
        <path d="M 35 46 L 36 56 L 36.5 66 L 36 74 L 35.2 82 L 34 84 L 33.5 74 L 34 64 L 34.5 54 Z" opacity="0.3"/>
        <path d="M 28 62 L 29 70 L 29.5 78 L 29 84 L 28 88 L 27 82 L 27.5 74 L 27.8 68 Z" opacity="0.25"/>
        <path d="M 62 42 L 63 52 L 63 62 L 62.5 70 L 62 76 L 61.5 68 L 62 58 L 62.3 50 Z" opacity="0.32"/>
        <path d="M 70 58 L 71 66 L 71 74 L 70.5 80 L 70 84 L 69.5 76 L 70 68 Z" opacity="0.28"/>
        <path d="M 78 70 L 79 76 L 79 82 L 78.5 86 L 78 88 L 77.5 82 L 78 76 Z" opacity="0.22"/>
      </g>

      <g clipPath={`url(#${id}-heroClip)`} fill={p.rockShade} opacity="0.55">
        <path d="M 50 22 L 51 20 L 52 24 L 50.5 25 Z"/>
        <path d="M 44 36 L 45 33 L 46.5 37 L 45 38 Z"/>
        <path d="M 38 52 L 39 49 L 40.5 53 L 39 54 Z"/>
        <path d="M 32 64 L 33 61 L 34.5 65 L 33 66 Z"/>
        <path d="M 58 26 L 58.7 24 L 59.5 27 L 58.7 28 Z" opacity="0.4"/>
        <path d="M 64 48 L 65 46 L 66 49 L 65 50 Z" opacity="0.45"/>
        <path d="M 73 64 L 74 62 L 75 65 L 74 66 Z" opacity="0.4"/>
      </g>

      <g clipPath={`url(#${id}-heroClip)`}>
        <path d={geo.snowMain} fill={`url(#${id}-snow)`}/>
        <path d="M 54 6 L 53 10 L 51 14 L 49 18 L 47 24 L 45 30 L 43 38 L 41 46 L 40 50 L 41 42 L 43 32 L 45 24 L 47 18 L 49 14 L 51 10 Z"
              fill={p.snowShade} opacity="0.6"/>
        {geo.couloirsShadow.map((c, i) => (
          <path key={`cs-${i}`} d={c} fill={p.snowShade} opacity={0.85 - i * 0.1}/>
        ))}
        {geo.couloirsLit.map((c, i) => (
          <path key={`cl-${i}`} d={c} fill={p.snowLit} opacity={0.9 - i * 0.1}/>
        ))}
        <path d="M 49 16 L 49.4 22 L 49.6 30 L 49.5 26" stroke={p.snowLit} strokeWidth="0.3" fill="none" opacity="0.5"/>
        <path d="M 44 28 L 44.3 36 L 44.5 44 L 44.4 38" stroke={p.snowLit} strokeWidth="0.25" fill="none" opacity="0.4"/>
        <ellipse cx="76" cy="70" rx="1.4" ry="0.5" fill={p.snowLit} opacity="0.5"/>
        <ellipse cx="83" cy="76" rx="1.1" ry="0.4" fill={p.snowLit} opacity="0.45"/>
        <ellipse cx="30" cy="72" rx="1.2" ry="0.4" fill={p.snowShade} opacity="0.5"/>
        <ellipse cx="22" cy="78" rx="1.0" ry="0.4" fill={p.snowShade} opacity="0.45"/>
      </g>

      <path d={geo.ridgeLineEast} stroke={p.sunColor} strokeWidth="0.35"
            fill="none" opacity={variant === 'cinematic' ? 0.8 : 0.45}/>
      <path d={geo.ridgeLineWest} stroke={p.rockShade} strokeWidth="0.3" fill="none" opacity="0.5"/>

      {(variant === 'cinematic' || (variant === 'painted' && timeOfDay !== 'night')) && (
        <g clipPath={`url(#${id}-heroClip)`}>
          <rect x="48" y="6" width="50" height="40" fill={`url(#${id}-alpenglow)`}/>
        </g>
      )}

      {variant === 'photo' && (
        <rect x="0" y="0" width="100" height="100" filter={`url(#${id}-grain)`} opacity="0.5"/>
      )}
      {variant === 'painted' && (
        <rect x="0" y="0" width="100" height="100" filter={`url(#${id}-brush)`} opacity="0.4"/>
      )}

      {variant === 'cinematic' && (
        <>
          <rect x="0" y="88" width="100" height="12" fill={p.rockShade} opacity="0.4"/>
          <rect x="0" y="0" width="100" height="100" fill={`url(#${id}-vignette)`}/>
        </>
      )}

      {variant === 'photo' && (
        <rect x="0" y="64" width="100" height="22" fill={p.haze} opacity="0.35"/>
      )}
    </g>
  );
}

export function PhotoRealistic({ timeOfDay = 'day' }: { timeOfDay?: TimeOfDay }) {
  const palettes: Record<TimeOfDay, Palette> = {
    dawn:  { skyTop:'#3F4866', skyMid:'#8C8090', skyHorizon:'#E8C5B0', sunPos:[78,30], sunColor:'#FFE0B5', haze:'#D8C8B8', rockBase:'#5A5860', rockLit:'#9088A0', rockShade:'#2F2C38', snowLit:'#F0EEEC', snowShade:'#A8B0C0', distance:'#9098A8' },
    day:   { skyTop:'#4878A8', skyMid:'#88B0D0', skyHorizon:'#C8DCE8', sunPos:[80,28], sunColor:'#FFFCEC', haze:'#B8C8D8', rockBase:'#5C5C5C', rockLit:'#A0A0A0', rockShade:'#2C2C2C', snowLit:'#F8F8F8', snowShade:'#A8B8C8', distance:'#8898A8' },
    dusk:  { skyTop:'#1F2F58', skyMid:'#684A78', skyHorizon:'#E89878', sunPos:[78,40], sunColor:'#FFB088', haze:'#C8A89C', rockBase:'#48404C', rockLit:'#90685A', rockShade:'#241C28', snowLit:'#E8C8B0', snowShade:'#7A6878', distance:'#8C7888' },
    night: { skyTop:'#04091C', skyMid:'#0E1A38', skyHorizon:'#2A3858', sunPos:[78,22], sunColor:'#E8E8FF', haze:'#3A4868', rockBase:'#1C2030', rockLit:'#3C4458', rockShade:'#08091A', snowLit:'#A8B8D8', snowShade:'#48587A', distance:'#283048' },
  };
  return <RealisticBase palette={palettes[timeOfDay]} timeOfDay={timeOfDay} variant="photo" id={`photo-${timeOfDay}`}/>;
}

export function PaintedRealistic({ timeOfDay = 'day' }: { timeOfDay?: TimeOfDay }) {
  const palettes: Record<TimeOfDay, Palette> = {
    dawn:  { skyTop:'#A86848', skyMid:'#E8A878', skyHorizon:'#F8DCB0', sunPos:[78,30], sunColor:'#FFE8C0', haze:'#E8B898', rockBase:'#6A4830', rockLit:'#C09060', rockShade:'#2A1812', snowLit:'#F8E8D0', snowShade:'#B89878', distance:'#A88878' },
    day:   { skyTop:'#5878A8', skyMid:'#A8C0D8', skyHorizon:'#F0E8C8', sunPos:[78,26], sunColor:'#FFF8D8', haze:'#D0C8A8', rockBase:'#6C5840', rockLit:'#B89870', rockShade:'#2C2018', snowLit:'#F8F0DC', snowShade:'#B0A088', distance:'#9C9078' },
    dusk:  { skyTop:'#581838', skyMid:'#B83C40', skyHorizon:'#F8B848', sunPos:[78,38], sunColor:'#FFC868', haze:'#D88858', rockBase:'#502820', rockLit:'#B8683C', rockShade:'#280C08', snowLit:'#F8C088', snowShade:'#A86848', distance:'#8C4838' },
    night: { skyTop:'#080828', skyMid:'#181848', skyHorizon:'#382C58', sunPos:[78,22], sunColor:'#F0E8D8', haze:'#382848', rockBase:'#1C1828', rockLit:'#48384C', rockShade:'#08081C', snowLit:'#B8A8C8', snowShade:'#4C3C58', distance:'#28283C' },
  };
  return <RealisticBase palette={palettes[timeOfDay]} timeOfDay={timeOfDay} variant="painted" id={`painted-${timeOfDay}`}/>;
}

export function CinematicRealistic({ timeOfDay = 'day' }: { timeOfDay?: TimeOfDay }) {
  const palettes: Record<TimeOfDay, Palette> = {
    dawn:  { skyTop:'#1A2858', skyMid:'#A04068', skyHorizon:'#F88848', sunPos:[80,32], sunColor:'#FFB060', haze:'#E07858', rockBase:'#4C2C30', rockLit:'#E07840', rockShade:'#1A0808', snowLit:'#FFC880', snowShade:'#806060', distance:'#684858' },
    day:   { skyTop:'#1858A0', skyMid:'#5898D8', skyHorizon:'#B8DCF0', sunPos:[80,24], sunColor:'#FFFCEC', haze:'#A8C8E0', rockBase:'#4C4438', rockLit:'#C8A878', rockShade:'#181410', snowLit:'#FFFFFC', snowShade:'#A0B0C8', distance:'#788CA8' },
    dusk:  { skyTop:'#181838', skyMid:'#683860', skyHorizon:'#F86838', sunPos:[80,40], sunColor:'#FF8838', haze:'#D85838', rockBase:'#3C2018', rockLit:'#F08038', rockShade:'#100400', snowLit:'#FFA858', snowShade:'#683848', distance:'#582838' },
    night: { skyTop:'#020414', skyMid:'#080A28', skyHorizon:'#181A38', sunPos:[80,22], sunColor:'#F0F0FF', haze:'#1C2038', rockBase:'#0E1020', rockLit:'#2C3048', rockShade:'#000004', snowLit:'#9CACD0', snowShade:'#384058', distance:'#101830' },
  };
  return <RealisticBase palette={palettes[timeOfDay]} timeOfDay={timeOfDay} variant="cinematic" id={`cine-${timeOfDay}`}/>;
}
