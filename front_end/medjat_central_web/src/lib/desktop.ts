/**
 * The bridge the Electron shell injects (see medjat_central_desktop/src/preload.js).
 *
 * Everything here is feature-detected: in a plain browser `window.medjat` does
 * not exist and the desktop-only paths simply never render.
 */

declare global {
  interface Window {
    medjat?: {
      isDesktop?: boolean;
      /**
       * Opens the system browser to sign in there, then returns over medjat://.
       * Naming a provider starts it straight away rather than showing the
       * login page again.
       */
      signInWithBrowser?: (provider?: "google" | "apple") => Promise<void>;
      retry?: () => Promise<void>;
      info?: () => Promise<{
        version: string;
        electron: string;
        platform: string;
        url: string;
      }>;
    };
  }
}

/** True only inside the desktop shell. Safe to call during SSR. */
export function isDesktopApp(): boolean {
  return typeof window !== "undefined" && window.medjat?.isDesktop === true;
}

/**
 * Whether this device can complete a passkey challenge.
 *
 * Electron has no platform authenticator, so a Google account protected by a
 * passkey dead-ends inside the app window — which is the whole reason the
 * browser sign-in path exists.
 */
export async function hasPlatformAuthenticator(): Promise<boolean> {
  if (typeof window === "undefined" || typeof PublicKeyCredential === "undefined") {
    return false;
  }
  try {
    return await PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable();
  } catch {
    return false;
  }
}

export {};
