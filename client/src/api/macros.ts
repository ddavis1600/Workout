import client from './client';
import type { UserProfile } from '../types';

export async function getProfile(): Promise<UserProfile> {
  const { data } = await client.get('/api/profile');
  return data;
}

export async function updateProfile(profile: Partial<UserProfile>): Promise<UserProfile> {
  const { data } = await client.put('/api/profile', profile);
  return data;
}

export async function calculateMacros(profile: Partial<UserProfile>): Promise<UserProfile> {
  const { data } = await client.post('/api/profile/calculate', profile);
  return data;
}
