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
    { media: "(prefers-color-scheme: light)", color: "#0E7C86" },
    { media: "(prefers-color-scheme: dark)", color: "#4FC6CC" },
  ],
  width: "device-width",
  initialScale: 1,
  maximumScale: 5,
};

export const metadata: Metadata = {
  title: {
    default: "Permedjat Central — لوحة إدارة الموارد البشرية",
    template: "%s | Permedjat Central",
  },
  description:
    "لوحة إدارة الموارد البشرية والرواتب — حضور وانصراف، رواتب، إجازات، تقارير.",
  manifest: "/manifest.json",
  icons: {
    icon: [
      { url: "/icons/favicon-32.png", sizes: "32x32", type: "image/png" },
      { url: "/icons/icon-192.png", sizes: "192x192", type: "image/png" },
      { url: "/icons/icon-512.png", sizes: "512x512", type: "image/png" },
    ],
    shortcut: "/icons/favicon-32.png",
    apple: "/icons/apple-icon.png",
  },
  appleWebApp: {
    capable: true,
    statusBarStyle: "default",
    title: "Permedjat Central",
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
