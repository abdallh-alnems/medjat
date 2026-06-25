"use client";

import { useState, useEffect } from "react";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
  SheetFooter,
  SheetClose,
} from "@/components/ui/sheet";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { MapPin } from "lucide-react";
import { useT } from "@/lib/i18n/use-t";
import { toast } from "sonner";
import type { Branch } from "@/lib/types";

interface Props {
  branch: Branch;
  onSave: (data: Partial<Branch>) => void;
}

/** Capture a branch geofence using the browser Geolocation API, with a manual lat/lng fallback. */
export function BranchLocationSheet({ branch, onSave }: Props) {
  const { t } = useT();
  const [open, setOpen] = useState(false);
  const [lat, setLat] = useState(String(branch.lat ?? ""));
  const [lng, setLng] = useState(String(branch.lng ?? ""));
  const [radius, setRadius] = useState(String(branch.radius ?? 100));

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setLat(String(branch.lat ?? ""));
    setLng(String(branch.lng ?? ""));
    setRadius(String(branch.radius ?? 100));
  }, [branch, open]);

  const useMyLocation = () => {
    if (typeof navigator === "undefined" || !navigator.geolocation) {
      toast.error(t("geolocation_denied"));
      return;
    }
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        setLat(String(pos.coords.latitude));
        setLng(String(pos.coords.longitude));
      },
      () => toast.error(t("geolocation_denied")),
      { enableHighAccuracy: true },
    );
  };

  const save = () => {
    onSave({
      lat: lat === "" ? null : isNaN(Number(lat)) ? null : Number(lat),
      lng: lng === "" ? null : isNaN(Number(lng)) ? null : Number(lng),
      radius: Number(radius) || 100,
    });
    setOpen(false);
  };

  return (
    <Sheet open={open} onOpenChange={setOpen}>
      <SheetTrigger render={<Button variant="outline" size="sm" />}>
        <MapPin className="h-4 w-4" />
        {t("branch_location")}
      </SheetTrigger>
      <SheetContent side="left" className="w-full max-w-sm space-y-4">
        <SheetHeader>
          <SheetTitle>{t("branch_location")}</SheetTitle>
        </SheetHeader>

        <Button variant="outline" className="w-full" onClick={useMyLocation}>
          <MapPin className="h-4 w-4" />
          {t("use_my_location")}
        </Button>

        <div className="space-y-1.5">
          <Label>{t("latitude")}</Label>
          <Input value={lat} onChange={(e) => setLat(e.target.value)} />
        </div>
        <div className="space-y-1.5">
          <Label>{t("longitude")}</Label>
          <Input value={lng} onChange={(e) => setLng(e.target.value)} />
        </div>
        <div className="space-y-1.5">
          <Label>{t("radius")}</Label>
          <Input
            type="number"
            value={radius}
            onChange={(e) => setRadius(e.target.value)}
          />
        </div>

        <SheetFooter>
          <SheetClose render={<Button variant="outline" />}>{t("cancel")}</SheetClose>
          <Button onClick={save}>{t("save")}</Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  );
}
