import Link from "next/link";
import Image from "next/image";

export default function AuthLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="flex min-h-dvh flex-col items-center justify-center bg-background px-4 py-8 sm:py-12">
      <Link
        href="/login"
        className="mb-6 flex flex-col items-center gap-2 text-center sm:mb-8"
      >
        <Image
          src="/logo.png"
          alt="Permedjat Central"
          width={64}
          height={64}
          priority
          className="h-14 w-14 rounded-2xl shadow-elev-sm sm:h-16 sm:w-16"
        />
        <span className="text-headline-sm font-bold text-foreground sm:text-headline-md">
          Permedjat Central
        </span>
      </Link>
      <div className="w-full max-w-md">{children}</div>
    </div>
  );
}
