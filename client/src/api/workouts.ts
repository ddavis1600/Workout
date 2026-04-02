import client from './client';
import type { Workout, ProgressPoint } from '../types';

export async function getWorkouts(from?: string, to?: string): Promise<Workout[]> {
  const params: Record<string, string> = {};
  if (from) params.from = from;
  if (to) params.to = to;
  const { data } = await client.get('/api/workouts', { params });
  return data;
}

export async function getWorkout(id: number): Promise<Workout> {
  const { data } = await client.get(`/api/workouts/${id}`);
  return data;
}

export async function createWorkout(workout: Partial<Workout>): Promise<Workout> {
  const { data } = await client.post('/api/workouts', workout);
  return data;
}

export async function updateWorkout(id: number, workout: Partial<Workout>): Promise<Workout> {
  const { data } = await client.put(`/api/workouts/${id}`, workout);
  return data;
}

export async function deleteWorkout(id: number): Promise<void> {
  await client.delete(`/api/workouts/${id}`);
}

export async function getExerciseProgress(exerciseId: number): Promise<ProgressPoint[]> {
  const { data } = await client.get(`/api/workouts/exercise/${exerciseId}/progress`);
  return data;
}
