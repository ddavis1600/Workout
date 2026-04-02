import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { getDiaryEntries, addDiaryEntry, updateDiaryEntry, deleteDiaryEntry, getDiarySummary } from '../api/diary';
import type { DiaryEntry } from '../types';
import toast from 'react-hot-toast';

export function useDiaryEntries(date: string) {
  return useQuery({
    queryKey: ['diary', date],
    queryFn: () => getDiaryEntries(date),
    enabled: !!date,
  });
}

export function useAddDiaryEntry() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (entry: Partial<DiaryEntry>) => addDiaryEntry(entry),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['diary'] });
      queryClient.invalidateQueries({ queryKey: ['diarySummary'] });
      toast.success('Food added!');
    },
    onError: () => {
      toast.error('Failed to add food');
    },
  });
}

export function useUpdateDiaryEntry() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, entry }: { id: number; entry: Partial<DiaryEntry> }) =>
      updateDiaryEntry(id, entry),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['diary'] });
      queryClient.invalidateQueries({ queryKey: ['diarySummary'] });
    },
    onError: () => {
      toast.error('Failed to update entry');
    },
  });
}

export function useDeleteDiaryEntry() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: number) => deleteDiaryEntry(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['diary'] });
      queryClient.invalidateQueries({ queryKey: ['diarySummary'] });
      toast.success('Entry removed');
    },
    onError: () => {
      toast.error('Failed to delete entry');
    },
  });
}

export function useDiarySummary(date: string) {
  return useQuery({
    queryKey: ['diarySummary', date],
    queryFn: () => getDiarySummary(date),
    enabled: !!date,
  });
}
