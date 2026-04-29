export const MOUNTAIN_PATH = [
  { x: 0.10, y: 0.95 },
  { x: 0.18, y: 0.85 },
  { x: 0.28, y: 0.78 },
  { x: 0.34, y: 0.68 },
  { x: 0.42, y: 0.58 },
  { x: 0.50, y: 0.48 },
  { x: 0.58, y: 0.40 },
  { x: 0.64, y: 0.32 },
  { x: 0.72, y: 0.24 },
  { x: 0.78, y: 0.18 },
  { x: 0.85, y: 0.12 },
  { x: 0.50, y: 0.08 },
];

export function pointOnPath(progress: number): { x: number; y: number } {
  const p = Math.max(0, Math.min(1, progress));
  if (p >= 1) return MOUNTAIN_PATH[MOUNTAIN_PATH.length - 1];
  const segs = MOUNTAIN_PATH.length - 1;
  const idx = p * segs;
  const i = Math.floor(idx);
  const t = idx - i;
  const a = MOUNTAIN_PATH[i];
  const b = MOUNTAIN_PATH[i + 1];
  return { x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t };
}

export const CAMPS = [
  { progress: 0.00, label: 'Basecamp' },
  { progress: 0.25, label: 'Camp I' },
  { progress: 0.50, label: 'Camp II' },
  { progress: 0.75, label: 'Camp III' },
  { progress: 1.00, label: 'Summit' },
];
