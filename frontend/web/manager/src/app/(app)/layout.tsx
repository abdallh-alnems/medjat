import { AppGuard } from "@/components/layout/app-guard";

export default function AppLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return <AppGuard>{children}</AppGuard>;
}
