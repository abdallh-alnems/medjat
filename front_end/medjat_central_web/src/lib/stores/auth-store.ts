"use client";

import { create } from "zustand";
import { persist } from "zustand/middleware";

export interface AuthUser {
  id: number | null;
  name: string | null;
  email: string | null;
  phone: string | null;
  photoUrl: string | null;
  firebaseUid: string | null;
  role: AdminRole | null;
  branchId: number | null;
  isActive: boolean;
  tenantId: number | null;
  permissions: Record<string, boolean> | null;
}

export type AdminRole =
  | "general_manager"
  | "hr"
  | "branch_manager"
  | "attendance"
  | "viewer";

interface AuthState {
  user: AuthUser | null;
  isLoggedIn: boolean;
  hasEverLoggedIn: boolean;
  setUser: (user: AuthUser | null) => void;
  setLoggedIn: (value: boolean) => void;
  updateUser: (data: Partial<AuthUser>) => void;
  logout: () => void;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      user: null,
      isLoggedIn: false,
      hasEverLoggedIn: false,
      setUser: (user) =>
        set((state) => ({
          user,
          isLoggedIn: user !== null,
          hasEverLoggedIn: state.hasEverLoggedIn || user !== null,
        })),
      setLoggedIn: (value) => set({ isLoggedIn: value }),
      updateUser: (data) =>
        set((state) => ({
          user: state.user ? { ...state.user, ...data } : null,
        })),
      logout: () =>
        set((state) => ({
          user: null,
          isLoggedIn: false,
          hasEverLoggedIn: state.hasEverLoggedIn,
        })),
    }),
    {
      name: "medjat-auth",
      partialize: (state) => ({
        user: state.user,
        isLoggedIn: state.isLoggedIn,
        hasEverLoggedIn: state.hasEverLoggedIn,
      }),
    },
  ),
);
