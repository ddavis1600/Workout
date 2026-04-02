import client from './client';
import type { Food } from '../types';

export async function searchFoods(query: string): Promise<Food[]> {
  const { data } = await client.get('/api/foods', { params: { q: query } });
  return data;
}

export async function createFood(food: Partial<Food>): Promise<Food> {
  const { data } = await client.post('/api/foods', food);
  return data;
}
