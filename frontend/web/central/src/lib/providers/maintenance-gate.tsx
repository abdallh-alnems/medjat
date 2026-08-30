"use client";

import { useEffect, useState } from "react";
import { fetchAndActivate, getValue } from "firebase/remote-config";
import { getRemoteConfigInstance } from "@/lib/firebase/config";
import { MaintenanceScreen } from "@/components/maintenance/maintenance-screen";

/**
 * Reads the Firebase Remote Config `maintenance_mode` flag (same project/keys as mobile,
 * D12) and gates the app behind a maintenance screen when active. No forced-update on web.
 */
export function MaintenanceGate({ children }: { children: React.ReactNode }) {
  const [status, setStatus] = useState<"loading" | "on" | "off">("loading");

  useEffect(() => {
    let active = false;
    const rc = getRemoteConfigInstance();
    if (!rc) {
      // No remote config on the server — disable the gate.
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setStatus("off");
      return;
    }
    fetchAndActivate(rc)
      .then(() => {
        if (active) return;
        const flag = getValue(rc, "maintenance_mode").asBoolean();
        setStatus(flag ? "on" : "off");
      })
      .catch(() => {
        if (!active) setStatus("off");
      });
    return () => {
      active = true;
    };
  }, []);

  if (status === "loading") return null;
  if (status === "on") return <MaintenanceScreen />;
  return <>{children}</>;
}
