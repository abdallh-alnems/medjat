import {
  GoogleAuthProvider,
  OAuthProvider,
  createUserWithEmailAndPassword,
  sendEmailVerification,
  sendPasswordResetEmail,
  signInWithCustomToken,
  signInWithEmailAndPassword,
  signInWithPopup,
  signInWithRedirect,
  getRedirectResult,
  signOut as fbSignOut,
  updatePassword as fbUpdatePassword,
  onAuthStateChanged,
} from "firebase/auth";
import { auth } from "./config";
import type { User } from "firebase/auth";

const googleProvider = new GoogleAuthProvider();

const appleProvider = new OAuthProvider("apple.com");
// Request the user's name + email on first Apple sign-in (Apple only returns
// these once, on the very first authorization).
appleProvider.addScope("email");
appleProvider.addScope("name");

/** Email + password. */
export async function signInEmail(email: string, password: string) {
  return signInWithEmailAndPassword(auth, email, password);
}

export async function signUpEmail(email: string, password: string) {
  return createUserWithEmailAndPassword(auth, email, password);
}

/**
 * Support-desk diagnostic sign-in.
 *
 * The token is minted by admin/admins/impersonate.php (super admin only, with a
 * stated reason, recorded in both our audit log and the company's own) and is
 * exchanged here for a normal session. Firebase expires it after one hour and
 * it cannot be renewed, so a forgotten tab dies on its own.
 */
export async function signInWithSupportToken(token: string) {
  return signInWithCustomToken(auth, token);
}

/**
 * Desktop sign-in.
 *
 * Electron reports no platform authenticator, so a Google account protected by a
 * passkey cannot finish signing in inside the app window. The user signs in in
 * their real browser instead, and the token minted by desktop_exchange.php
 * carries that session back here.
 */
export async function signInWithDesktopToken(token: string) {
  return signInWithCustomToken(auth, token);
}

// Popup-failure codes where a full-page redirect is the better fallback.
const REDIRECT_FALLBACK_CODES = new Set([
  "auth/popup-blocked",
  "auth/operation-not-supported-in-this-environment",
  "auth/web-storage-unsupported",
]);

/**
 * Social sign-in. Tries popup first (reliable on localhost, works across the
 * firebaseapp.com auth domain via postMessage). If the popup is blocked/unsupported,
 * falls back to a full-page redirect — completion then happens via
 * `consumeRedirectResult()` on return. Returns the credential on popup success,
 * or null when a redirect was started (the page navigates away).
 */
async function oauthSignIn(provider: GoogleAuthProvider | OAuthProvider) {
  try {
    return await signInWithPopup(auth, provider);
  } catch (err) {
    const code = (err as { code?: string })?.code ?? "";
    if (REDIRECT_FALLBACK_CODES.has(code)) {
      await signInWithRedirect(auth, provider);
      return null;
    }
    throw err;
  }
}

/** Google sign-in (popup, redirect fallback). */
export async function signInWithGoogle() {
  return oauthSignIn(googleProvider);
}

/** Apple sign-in (popup, redirect fallback). */
export async function signInWithApple() {
  return oauthSignIn(appleProvider);
}

/** Resolves a pending redirect sign-in (call on login mount). Returns the
 *  signed-in user when a redirect just completed, or null otherwise. */
export async function consumeRedirectResult(): Promise<User | null> {
  const result = await getRedirectResult(auth);
  return result?.user ?? null;
}

export async function signOut() {
  return fbSignOut(auth);
}

export async function getAuthToken(): Promise<string | null> {
  const user = auth.currentUser;
  if (!user) return null;
  return user.getIdToken();
}

export function getCurrentUser(): User | null {
  return auth.currentUser;
}

export function onAuthChange(cb: (user: User | null) => void) {
  return onAuthStateChanged(auth, cb);
}

export async function resendEmailVerification(user: User) {
  return sendEmailVerification(user);
}

export async function sendPasswordReset(email: string) {
  return sendPasswordResetEmail(auth, email);
}

/** Set a new password for the signed-in user (used after reset). */
export async function updateCurrentUserPassword(newPassword: string) {
  const user = auth.currentUser;
  if (!user) throw new Error("Not signed in");
  return fbUpdatePassword(user, newPassword);
}
