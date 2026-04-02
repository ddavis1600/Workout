import client from './client';
import type { Exercise } from '../types';

export async function getExercises(muscleGroup?: string): Promise<Exercise[]> {
  const params: Record<string, string> = {};
  if (muscleGroup) params.muscle_group = muscleGroup;
  const { data } = await client.get('/api/exercises', { params });
  return data;
}

export async function createExercise(exercise: Partial<Exercise>): Promise<Exercise> {
  const { data } = await client.post('/api/exercises', exercise);
  return data;
}
