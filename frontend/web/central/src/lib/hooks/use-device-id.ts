"use client";

import { useEffect, useState } from "react";
import { getDeviceId } from "@/lib/api/client";

/** React hook returning the stable per-browser device id (client-only). */
export function useDeviceId(): string {
  const [deviceId, setDeviceId] = useState<string>("ssr");
  useEffect(() => {
    // Device id is only computable in the browser (localStorage).
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setDeviceId(getDeviceId());
  }, []);
  return deviceId;
}
