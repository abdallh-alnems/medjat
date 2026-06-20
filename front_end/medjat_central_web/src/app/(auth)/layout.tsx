import Link from "next/link";
import { Building2 } from "lucide-react";

export default function AuthLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-background px-4 py-10">
      <Link
        href="/login"
        className="mb-8 flex flex-col items-center gap-2 text-center"
      >
        <div className="flex h-12 w-12 items-center justify-center rounded-xl bg-brand text-brand-foreground">
          <Building2 className="h-6 w-6" />
        </div>
        <span className="text-headline-md font-bold text-foreground">
          Medjat Central
        </span>
      </Link>
      <div className="w-full max-w-md">{children}</div>
    </div>
  );
}
