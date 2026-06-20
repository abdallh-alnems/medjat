import { Wrench } from "lucide-react";

export function MaintenanceScreen() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-4 bg-background px-6 text-center">
      <div className="flex h-16 w-16 items-center justify-center rounded-full bg-brand-subtle text-brand">
        <Wrench className="h-8 w-8" />
      </div>
      <h1 className="text-headline-lg font-bold text-foreground">
        الصيانة جارية
      </h1>
      <p className="max-w-md text-body-md text-muted-foreground">
        نعمل حالياً على تحسين النظام. سنعود قريباً. شكراً لصبرك.
      </p>
    </div>
  );
}
