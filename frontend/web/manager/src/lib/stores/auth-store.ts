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

/** A team invitation addressed to the signed-in user's email, surfaced on
 *  onboarding so they can join with one tap (no code needed). */
export interface PendingInvitation {
  invitation_id: number;
  company_name: string;
  role: AdminRole;
  role_key: AdminRole;
  branch_name: string | null;
  expires_at: string;
}

interface AuthState {
  user: AuthUser | null;
  isLoggedIn: boolean;
  hasEverLoggedIn: boolean;
  pendingInvitation: PendingInvitation | null;
  setUser: (user: AuthUser | null) => void;
  setLoggedIn: (value: boolean) => void;
  updateUser: (data: Partial<AuthUser>) => void;
  setPendingInvitation: (invitation: PendingInvitation | null) => void;
  logout: () => void;
}

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      user: null,
      isLoggedIn: false,
      hasEverLoggedIn: false,
      pendingInvitation: null,
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
      setPendingInvitation: (invitation) =>
        set({ pendingInvitation: invitation }),
      logout: () =>
        set((state) => ({
          user: null,
          isLoggedIn: false,
          hasEverLoggedIn: state.hasEverLoggedIn,
          pendingInvitation: null,
        })),
    }),
    {
      name: "permedjat-auth",
      partialize: (state) => ({
        user: state.user,
        isLoggedIn: state.isLoggedIn,
        hasEverLoggedIn: state.hasEverLoggedIn,
        pendingInvitation: state.pendingInvitation,
      }),
    },
  ),
);
