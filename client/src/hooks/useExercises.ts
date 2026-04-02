import { useQuery } from '@tanstack/react-query';
import { getExercises } from '../api/exercises';

export function useExercises(muscleGroup?: string) {
  return useQuery({
    queryKey: ['exercises', muscleGroup],
    queryFn: () => getExercises(muscleGroup),
  });
}
