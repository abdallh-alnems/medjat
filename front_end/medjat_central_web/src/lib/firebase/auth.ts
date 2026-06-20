import {
  GoogleAuthProvider,
  OAuthProvider,
  createUserWithEmailAndPassword,
  sendEmailVerification,
  sendPasswordResetEmail,
  signInWithEmailAndPassword,
  signInWithPopup,
  signOut as fbSignOut,
  updatePassword as fbUpdatePassword,
  onAuthStateChanged,
} from "firebase/auth";
import { auth } from "./config";
import type { User } from "firebase/auth";

const googleProvider = new GoogleAuthProvider();
const appleProvider = new OAuthProvider("apple.com");

/** Email + password. */
export async function signInEmail(email: string, password: string) {
  return signInWithEmailAndPassword(auth, email, password);
}

export async function signUpEmail(email: string, password: string) {
  return createUserWithEmailAndPassword(auth, email, password);
}

/** Google popup. */
export async function signInWithGoogle() {
  return signInWithPopup(auth, googleProvider);
}

/** Apple OAuth popup. */
export async function signInWithApple() {
  return signInWithPopup(auth, appleProvider);
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
