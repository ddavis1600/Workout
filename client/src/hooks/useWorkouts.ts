import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { getWorkouts, getWorkout, createWorkout, updateWorkout, deleteWorkout, getExerciseProgress } from '../api/workouts';
import type { Workout } from '../types';
import toast from 'react-hot-toast';

export function useWorkouts(from?: string, to?: string) {
  return useQuery({
    queryKey: ['workouts', from, to],
    queryFn: () => getWorkouts(from, to),
  });
}

export function useWorkout(id: number) {
  return useQuery({
    queryKey: ['workout', id],
    queryFn: () => getWorkout(id),
    enabled: !!id,
  });
}

export function useCreateWorkout() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (workout: Partial<Workout>) => createWorkout(workout),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['workouts'] });
      toast.success('Workout saved!');
    },
    onError: () => {
      toast.error('Failed to save workout');
    },
  });
}

export function useUpdateWorkout() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, workout }: { id: number; workout: Partial<Workout> }) =>
      updateWorkout(id, workout),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['workouts'] });
      toast.success('Workout updated!');
    },
    onError: () => {
      toast.error('Failed to update workout');
    },
  });
}

export function useDeleteWorkout() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: number) => deleteWorkout(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['workouts'] });
      toast.success('Workout deleted');
    },
    onError: () => {
      toast.error('Failed to delete workout');
    },
  });
}

export function useExerciseProgress(exerciseId: number) {
  return useQuery({
    queryKey: ['exerciseProgress', exerciseId],
    queryFn: () => getExerciseProgress(exerciseId),
    enabled: !!exerciseId,
  });
}
