import client from './client';
import type { DiaryEntry, MacroSummary } from '../types';

export async function getDiaryEntries(date: string): Promise<DiaryEntry[]> {
  const { data } = await client.get('/api/diary', { params: { date } });
  return data;
}

export async function addDiaryEntry(entry: Partial<DiaryEntry>): Promise<DiaryEntry> {
  const { data } = await client.post('/api/diary', entry);
  return data;
}

export async function updateDiaryEntry(id: number, entry: Partial<DiaryEntry>): Promise<DiaryEntry> {
  const { data } = await client.put(`/api/diary/${id}`, entry);
  return data;
}

export async function deleteDiaryEntry(id: number): Promise<void> {
  await client.delete(`/api/diary/${id}`);
}

export async function getDiarySummary(date: string): Promise<MacroSummary> {
  const { data } = await client.get('/api/diary/summary', { params: { date } });
  return data;
}
