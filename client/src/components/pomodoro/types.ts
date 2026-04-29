export type ArtStyle = 'realistic' | 'topo' | 'papercut' | 'pixel';
export type TimeOfDay = 'dawn' | 'day' | 'dusk' | 'night';
export type ClimberVariant = 'solo' | 'dog' | 'rope';
export type PapercutVariant = 'classic' | 'serene' | 'epic';
export type RealisticVariant = 'photo' | 'painted' | 'cinematic';

export interface Tweaks {
  artStyle: ArtStyle;
  timeOfDay: TimeOfDay;
  climberType: ClimberVariant;
  papercutVariant: PapercutVariant;
  realisticVariant: RealisticVariant;
}

export interface Peak {
  name: string;
  elev: number;
  date: string;
  sessions: number;
  climber: ClimberVariant;
  style: ArtStyle;
}
