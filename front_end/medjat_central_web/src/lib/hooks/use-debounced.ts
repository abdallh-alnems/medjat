"use client";

import { useRef, useCallback, useEffect } from "react";

/** Debounce a callback by `delay` ms. */
export function useDebouncedCallback<T extends (...args: never[]) => void>(
  callback: T,
  delay: number,
) {
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    return () => {
      if (timerRef.current) clearTimeout(timerRef.current);
    };
  }, []);

  return useCallback(
    (...args: Parameters<T>) => {
      if (timerRef.current) clearTimeout(timerRef.current);
      timerRef.current = setTimeout(() => callback(...args), delay);
    },
    [callback, delay],
  );
}
