import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { Toaster } from 'react-hot-toast';
import AppShell from './components/layout/AppShell';
import DashboardPage from './pages/DashboardPage';
import WorkoutPage from './pages/WorkoutPage';
import WorkoutHistoryPage from './pages/WorkoutHistoryPage';
import ExerciseProgressPage from './pages/ExerciseProgressPage';
import MacrosPage from './pages/MacrosPage';
import DiaryPage from './pages/DiaryPage';
import FocusPage from './pages/FocusPage';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60 * 2,
      retry: 1,
    },
  },
});

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <AppShell>
          <Routes>
            <Route path="/" element={<DashboardPage />} />
            <Route path="/workouts" element={<WorkoutPage />} />
            <Route path="/workouts/history" element={<WorkoutHistoryPage />} />
            <Route path="/progress" element={<ExerciseProgressPage />} />
            <Route path="/macros" element={<MacrosPage />} />
            <Route path="/diary" element={<DiaryPage />} />
            <Route path="/focus" element={<FocusPage />} />
          </Routes>
        </AppShell>
        <Toaster
          position="bottom-right"
          toastOptions={{
            style: {
              background: '#1e293b',
              color: '#e2e8f0',
              border: '1px solid #334155',
            },
            success: {
              iconTheme: { primary: '#10b981', secondary: '#fff' },
            },
            error: {
              iconTheme: { primary: '#ef4444', secondary: '#fff' },
            },
          }}
        />
      </BrowserRouter>
    </QueryClientProvider>
  );
}
