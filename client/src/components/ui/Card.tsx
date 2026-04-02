import type { ReactNode } from 'react';

interface CardProps extends React.HTMLAttributes<HTMLDivElement> {
  children: ReactNode;
  className?: string;
}

export default function Card({ children, className = '', ...props }: CardProps) {
  return (
    <div className={`bg-slate-800 rounded-xl p-6 border border-slate-700 ${className}`} {...props}>
      {children}
    </div>
  );
}
