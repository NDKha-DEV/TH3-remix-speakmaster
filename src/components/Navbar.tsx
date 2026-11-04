import React from 'react';
import { User } from 'firebase/auth';
import { UserProfile } from '../types';
import {
  Flame,
  Award,
  Smartphone,
  Monitor
} from 'lucide-react';

interface NavbarProps {
  currentUser: User | null;
  userProfile: UserProfile | null;
  onOpenAuth: () => void;
  isMobileFrame: boolean;
  onToggleMobileFrame: () => void;
}

export const Navbar: React.FC<NavbarProps> = ({
  currentUser,
  userProfile,
  onOpenAuth,
  isMobileFrame,
  onToggleMobileFrame,
}) => {
  const streak = userProfile?.streakCount || 1;
  const xp = userProfile?.totalXp || 100;
  const level = userProfile?.level || 1;

  return (
    <header className="sticky top-0 z-40 bg-white/80 dark:bg-slate-900/80 backdrop-blur-md border-b border-slate-200 dark:border-slate-800 transition-colors">
      <div className="max-w-5xl mx-auto px-4 py-3 flex items-center justify-between gap-2">
        {/* Brand & Logo */}
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-2xl bg-gradient-to-tr from-emerald-500 via-teal-500 to-cyan-500 text-white flex items-center justify-center font-black text-xl shadow-md shadow-emerald-500/20">
            S
          </div>
          <div>
            <div className="flex items-center gap-1.5">
              <h1 className="font-extrabold text-base md:text-lg text-slate-800 dark:text-white tracking-tight">
                SpeakMaster
              </h1>
              <span className="px-1.5 py-0.2 rounded-md bg-emerald-500/15 text-[10px] font-black uppercase text-emerald-600 dark:text-emerald-400">
                AI Pronounce
              </span>
            </div>
            <p className="text-[11px] text-slate-400 hidden sm:block">
              Chuỗi Kỷ Luật & AI Chấm Điểm Âm Vị
            </p>
          </div>
        </div>

        {/* Center/Right metrics & actions */}
        <div className="flex items-center gap-2 md:gap-3">
          {/* Streak pill */}
          <div
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-amber-500/10 border border-amber-500/20 text-amber-600 dark:text-amber-400 text-xs font-black shadow-sm"
            title={`Chuỗi kỷ luật: ${streak} ngày liên tiếp`}
          >
            <Flame className="w-4 h-4 text-amber-500 fill-amber-500 animate-pulse" />
            <span>{streak} Ngày</span>
          </div>

          {/* XP & Level pill */}
          <div
            className="hidden sm:flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-emerald-500/10 border border-emerald-500/20 text-emerald-600 dark:text-emerald-400 text-xs font-black"
            title={`Cấp độ ${level} (${xp} XP)`}
          >
            <Award className="w-4 h-4 text-emerald-500" />
            <span>Cấp {level}</span>
          </div>

          {/* Mobile Frame Toggle */}
          <button
            onClick={onToggleMobileFrame}
            className="p-2 rounded-2xl bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 text-slate-600 dark:text-slate-300 transition"
            title={isMobileFrame ? 'Chuyển sang Giao diện Rộng' : 'Chuyển sang Khung Điện Thoại'}
          >
            {isMobileFrame ? <Monitor className="w-4 h-4" /> : <Smartphone className="w-4 h-4 text-emerald-500" />}
          </button>

          {/* User Auth Profile / Login */}
          <button
            onClick={onOpenAuth}
            className="flex items-center gap-2 pl-2 pr-3 py-1.5 rounded-2xl bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 transition"
          >
            {currentUser?.photoURL ? (
              <img
                src={currentUser.photoURL}
                alt="user"
                className="w-6 h-6 rounded-full border border-emerald-500 object-cover"
              />
            ) : (
              <div className="w-6 h-6 rounded-full bg-emerald-500 text-white flex items-center justify-center font-bold text-xs">
                {(userProfile?.displayName || currentUser?.email || 'U')[0].toUpperCase()}
              </div>
            )}
            <span className="text-xs font-semibold text-slate-700 dark:text-slate-200 max-w-[80px] sm:max-w-[120px] truncate">
              {userProfile?.displayName || (currentUser ? 'Học viên' : 'Đăng nhập')}
            </span>
          </button>
        </div>
      </div>
    </header>
  );
};
