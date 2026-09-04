import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "تثبيت التطبيق",
  description:
    "ثبّت Permedjat Central على جهازك كتطبيق مستقل — دون تنزيل أي ملف ودون تحذيرات.",
};

export default function InstallLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return children;
}
