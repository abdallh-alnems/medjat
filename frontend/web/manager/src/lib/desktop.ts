/**
 * The bridge the Electron shell injects (see frontend/desktop/manager/src/preload.js).
 *
 * Everything here is feature-detected: in a plain browser `window.medjat` does
 * not exist and the desktop-only paths simply never render.
 */

declare global {
  interface Window {
    medjat?: {
      isDesktop?: boolean;
      /** Opens the system browser to sign in there, then returns over medjat://. */
      signInWithBrowser?: () => Promise<void>;
      /**
       * Reads the attendance log off a ZKTeco terminal on the local network.
       * Resolves with `ok: false` rather than rejecting, so the caller always
       * has the device's own error text to show.
       */
      readDevice?: (options: { ip: string; port?: number }) => Promise<
        | {
            ok: true;
            device: {
              ip: string;
              port: number;
              name: string | null;
              serial: string | null;
              firmware: string | null;
              clock: string | null;
            };
            rows: { userId: string; at: string }[];
            csv: string;
            total: number;
            truncated: boolean;
          }
        | { ok: false; error: string }
      >;
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
