"use client";

import { useCallback } from "react";
import { getAuthToken } from "@/lib/firebase/auth";

/** Returns the current Firebase ID token (or null if signed out). */
export function useAuthToken() {
  return useCallback(async () => {
    return getAuthToken();
  }, []);
}

export { getAuthToken };
