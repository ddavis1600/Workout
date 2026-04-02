import type { ReactNode } from 'react';
import Sidebar from './Sidebar';

interface AppShellProps {
  children: ReactNode;
}

export default function AppShell({ children }: AppShellProps) {
  return (
    <div className="min-h-screen bg-slate-900 text-slate-100">
      <Sidebar />
      <main className="md:ml-60 p-4 md:p-8 pb-24 md:pb-8">
        {children}
      </main>
    </div>
  );
}
