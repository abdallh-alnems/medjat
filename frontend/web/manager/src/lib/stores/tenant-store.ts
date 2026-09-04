"use client";

import { create } from "zustand";
import { persist } from "zustand/middleware";

interface TenantState {
  tenantId: number | null;
  tenantName: string | null;
  setTenant: (id: number, name?: string) => void;
  clearTenant: () => void;
}

export const useTenantStore = create<TenantState>()(
  persist(
    (set) => ({
      tenantId: null,
      tenantName: null,
      setTenant: (id, name) => set({ tenantId: id, tenantName: name ?? null }),
      clearTenant: () => set({ tenantId: null, tenantName: null }),
    }),
    {
      name: "permedjat-tenant",
    },
  ),
);
