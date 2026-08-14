/**
 * Install state for the app-install (PWA) path.
 *
 * `beforeinstallprompt` fires once, early, on whichever page the browser opened
 * first — almost never /install. Capturing it globally from `PwaProvider` and
 * holding it here is what lets the install page offer a real one-click button
 * minutes later instead of a paragraph of instructions.
 *
 * Everything degrades: browsers that never fire the event (Safari, Firefox) leave
 * `canPrompt` false and the page falls back to per-platform steps.
 */

interface BeforeInstallPromptEvent extends Event {
  readonly platforms: string[];
  readonly userChoice: Promise<{
    outcome: "accepted" | "dismissed";
    platform: string;
  }>;
  prompt(): Promise<void>;
}

export type InstallState = {
  /** A prompt is in hand — the page can install with one click. */
  canPrompt: boolean;
  /** Already running as an installed app, so there is nothing to offer. */
  standalone: boolean;
  /** Installed during this visit; the captured prompt is spent. */
  justInstalled: boolean;
};

/**
 * Frozen so SSR and the first client render agree. `useSyncExternalStore` compares
 * snapshots by reference, so this must be the same object every time.
 */
const SERVER_STATE: InstallState = Object.freeze({
  canPrompt: false,
  standalone: false,
  justInstalled: false,
});

let deferred: BeforeInstallPromptEvent | null = null;
let state: InstallState = SERVER_STATE;
let started = false;
const listeners = new Set<() => void>();

function setState(patch: Partial<InstallState>) {
  const next = { ...state, ...patch };
  if (
    next.canPrompt === state.canPrompt &&
    next.standalone === state.standalone &&
    next.justInstalled === state.justInstalled
  ) {
    return;
  }
  state = next;
  for (const listener of listeners) listener();
}

/** True when the page is running in an installed window rather than a tab. */
export function isStandalone(): boolean {
  if (typeof window === "undefined") return false;
  const iosInstalled = (window.navigator as { standalone?: boolean }).standalone;
  return (
    window.matchMedia?.("(display-mode: standalone)").matches === true ||
    window.matchMedia?.("(display-mode: window-controls-overlay)").matches === true ||
    iosInstalled === true
  );
}

/**
 * Starts listening. Safe to call more than once — only the first call binds.
 * Returns a teardown for the provider's effect.
 */
export function startInstallCapture(): () => void {
  if (typeof window === "undefined" || started) return () => {};
  started = true;

  const onBeforePrompt = (event: Event) => {
    // Holding the event is what keeps the button live; without preventDefault
    // Chrome shows its own mini-infobar and discards it.
    event.preventDefault();
    deferred = event as BeforeInstallPromptEvent;
    setState({ canPrompt: true });
  };

  const onInstalled = () => {
    deferred = null;
    setState({ canPrompt: false, justInstalled: true });
  };

  window.addEventListener("beforeinstallprompt", onBeforePrompt);
  window.addEventListener("appinstalled", onInstalled);

  // Opening the installed window later should retire the offer in this tab too.
  const standaloneQuery = window.matchMedia?.("(display-mode: standalone)");
  const onDisplayModeChange = () => setState({ standalone: isStandalone() });
  standaloneQuery?.addEventListener?.("change", onDisplayModeChange);

  setState({ standalone: isStandalone() });

  return () => {
    window.removeEventListener("beforeinstallprompt", onBeforePrompt);
    window.removeEventListener("appinstalled", onInstalled);
    standaloneQuery?.removeEventListener?.("change", onDisplayModeChange);
    started = false;
  };
}

export function subscribeInstall(callback: () => void): () => void {
  listeners.add(callback);
  return () => listeners.delete(callback);
}

export function getInstallState(): InstallState {
  return state;
}

export function getServerInstallState(): InstallState {
  return SERVER_STATE;
}

/**
 * Shows the browser's own install dialog.
 *
 * The captured event is single-use whatever the user answers, so a dismissal
 * means the button has to become instructions until the browser offers again.
 */
export async function promptInstall(): Promise<
  "accepted" | "dismissed" | "unavailable"
> {
  const event = deferred;
  if (!event) return "unavailable";
  deferred = null;
  setState({ canPrompt: false });
  try {
    await event.prompt();
    const { outcome } = await event.userChoice;
    return outcome;
  } catch {
    return "unavailable";
  }
}

export type Platform = "windows" | "macos" | "ios" | "android" | "linux" | "other";
export type Browser = "edge" | "chrome" | "safari" | "firefox" | "other";

/**
 * UA sniffing, deliberately. This picks which *instructions* to show, so being
 * approximately right beats being unable to say anything at all — and every
 * platform's steps stay reachable under "other platforms".
 */
export function detectPlatform(): Platform {
  if (typeof navigator === "undefined") return "other";
  const ua = navigator.userAgent;
  const hinted = (
    navigator as { userAgentData?: { platform?: string } }
  ).userAgentData?.platform?.toLowerCase();

  if (/iPhone|iPad|iPod/.test(ua)) return "ios";
  // iPadOS reports itself as a Mac; the touch points give it away.
  if (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1) return "ios";
  if (/Android/.test(ua)) return "android";
  if (hinted?.includes("win") || /Windows/.test(ua)) return "windows";
  if (hinted?.includes("mac") || /Macintosh|Mac OS X/.test(ua)) return "macos";
  if (hinted?.includes("linux") || /Linux/.test(ua)) return "linux";
  return "other";
}

export function detectBrowser(): Browser {
  if (typeof navigator === "undefined") return "other";
  const ua = navigator.userAgent;

  // Order matters: Edge carries "Chrome", and Chrome carries "Safari".
  if (/Edg\//.test(ua)) return "edge";
  if (/Firefox\/|FxiOS\//.test(ua)) return "firefox";
  if (/CriOS\//.test(ua)) return "chrome";
  if (/Chrome\/|Chromium\//.test(ua)) return "chrome";
  if (/Safari\//.test(ua)) return "safari";
  return "other";
}

/**
 * Whether this browser can install at all. Firefox has no install path on
 * desktop, so pointing its users at Edge or Chrome is the only honest answer.
 */
export function canInstallHere(platform: Platform, browser: Browser): boolean {
  if (browser === "firefox") return platform === "android";
  if (platform === "ios") return browser === "safari";
  return true;
}

export type Environment = { platform: Platform; browser: Browser };

let environment: Environment | null = null;

/**
 * The visitor's platform and browser, read through `useSyncExternalStore` so the
 * server renders nothing and the client fills it in after hydration. It never
 * changes, hence the no-op subscribe; the cached object keeps the snapshot
 * reference stable, which the store requires.
 */
export function subscribeEnvironment(): () => void {
  return () => {};
}

export function getEnvironment(): Environment | null {
  if (typeof window === "undefined") return null;
  environment ??= { platform: detectPlatform(), browser: detectBrowser() };
  return environment;
}

export function getServerEnvironment(): Environment | null {
  return null;
}
