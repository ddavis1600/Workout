import { format, parseISO } from 'date-fns';

export function formatDate(dateStr: string, fmt: string = 'MMM d, yyyy'): string {
  try {
    return format(parseISO(dateStr), fmt);
  } catch {
    return dateStr;
  }
}

export function formatWeight(value: number, unit: string = 'imperial'): string {
  if (unit === 'metric') {
    return `${formatNumber(value)} kg`;
  }
  return `${formatNumber(value)} lbs`;
}

export function formatNumber(value: number, decimals: number = 1): string {
  if (value == null) return '0';
  return Number(value).toFixed(decimals).replace(/\.0$/, '');
}
