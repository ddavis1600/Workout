import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { getProfile, updateProfile, calculateMacros } from '../api/macros';
import type { UserProfile } from '../types';
import toast from 'react-hot-toast';

export function useProfile() {
  return useQuery({
    queryKey: ['profile'],
    queryFn: getProfile,
  });
}

export function useUpdateProfile() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (profile: Partial<UserProfile>) => updateProfile(profile),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['profile'] });
      toast.success('Profile saved!');
    },
    onError: () => {
      toast.error('Failed to save profile');
    },
  });
}

export function useCalculateMacros() {
  return useMutation({
    mutationFn: (profile: Partial<UserProfile>) => calculateMacros(profile),
  });
}
