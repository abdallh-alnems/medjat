import type { Metadata, Viewport } from "next";
import { IBM_Plex_Sans_Arabic, Geist } from "next/font/google";
import { Toaster } from "@/components/ui/sonner";
import { ThemeProvider } from "@/lib/providers/theme-provider";
import { QueryProvider } from "@/lib/providers/query-provider";
import { PwaProvider } from "@/lib/providers/pwa-provider";
import { I18nProvider } from "@/lib/providers/i18n-provider";
import { MaintenanceGate } from "@/lib/providers/maintenance-gate";
import "./globals.css";

const ibmPlexArabic = IBM_Plex_Sans_Arabic({
  subsets: ["arabic", "latin"],
  weight: ["300", "400", "500", "600", "700"],
  variable: "--font-ibm-plex-arabic",
  display: "swap",
});

const geist = Geist({
  subsets: ["latin"],
  variable: "--font-geist",
  display: "swap",
});

export const viewport: Viewport = {
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#2563EB" },
    { media: "(prefers-color-scheme: dark)", color: "#60A5FA" },
  ],
  width: "device-width",
  initialScale: 1,
  maximumScale: 5,
};

export const metadata: Metadata = {
  title: {
    default: "Medjat Central — لوحة إدارة الموارد البشرية",
    template: "%s | Medjat Central",
  },
  description:
    "لوحة إدارة الموارد البشرية والرواتب — حضور وانصراف، رواتب، إجازات، تقارير.",
  manifest: "/manifest.json",
  icons: {
    icon: "/icons/icon.svg",
    shortcut: "/icons/icon.svg",
    apple: "/icons/icon.svg",
  },
  appleWebApp: {
    capable: true,
    statusBarStyle: "default",
    title: "Medjat Central",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html
      lang="ar"
      dir="rtl"
      className={`${ibmPlexArabic.variable} ${geist.variable} h-full antialiased`}
      suppressHydrationWarning
    >
      <body
        className="min-h-full flex flex-col font-sans"
        suppressHydrationWarning
      >
        <ThemeProvider
          attribute="class"
          defaultTheme="system"
          enableSystem
          disableTransitionOnChange
        >
          <QueryProvider>
            <PwaProvider>
              <I18nProvider>
                <MaintenanceGate>{children}</MaintenanceGate>
                <Toaster
                  position="bottom-center"
                  dir="rtl"
                  richColors
                  closeButton
                />
              </I18nProvider>
            </PwaProvider>
          </QueryProvider>
        </ThemeProvider>
      </body>
    </html>
  );
}
