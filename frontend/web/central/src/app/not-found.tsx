import Link from "next/link";
import { Button } from "@/components/ui/button";

/** 404 not-found page. */
export default function NotFound() {
  return (
    <div className="flex min-h-[60vh] flex-col items-center justify-center gap-4 text-center">
      <p className="text-headline-lg font-bold text-muted-foreground">٤٠٤</p>
      <h1 className="text-headline-md font-bold">الصفحة غير موجودة</h1>
      <p className="text-body-md text-muted-foreground">
        قد يكون الرابط غير صحيح أو أن الصفحة تم نقلها.
      </p>
      <Button render={<Link href="/dashboard" />}>العودة للرئيسية</Button>
    </div>
  );
}
