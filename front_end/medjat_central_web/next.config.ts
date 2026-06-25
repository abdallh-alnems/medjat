import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  async redirects() {
    return [
      // Send the root straight to /login at the routing layer. Doing this here
      // (instead of a `redirect()` inside a root page component) avoids React
      // 19.2's dev-only Performance Tracks throwing "'Home' cannot have a
      // negative time stamp" while measuring a component that throws on render.
      {
        source: "/",
        destination: "/login",
        permanent: false,
      },
    ];
  },
  async headers() {
    return [
      {
        // Allow Firebase signInWithPopup to keep the opener↔popup relationship so
        // the credential can post back. Without this, COOP isolation interferes
        // with the popup sign-in flow.
        source: "/:path*",
        headers: [
          {
            key: "Cross-Origin-Opener-Policy",
            value: "same-origin-allow-popups",
          },
        ],
      },
    ];
  },
};

export default nextConfig;
