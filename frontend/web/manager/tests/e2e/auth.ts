import type { Page } from "@playwright/test";

/**
 * Shared login helper for e2e tests. Performs the Firebase email/password login
 * flow using E2E_EMAIL / E2E_PASSWORD env vars. Call in a test.beforeEach hook
 * for any suite that navigates to protected routes.
 */
export async function login(page: Page): Promise<void> {
  const email = process.env.E2E_EMAIL ?? "";
  const password = process.env.E2E_PASSWORD ?? "";
  if (!email || !password) {
    throw new Error(
      "E2E_EMAIL and E2E_PASSWORD must be set before running e2e tests.",
    );
  }
  await page.goto("/login");
  await page.getByLabel(/email/i).fill(email);
  await page.getByLabel(/password/i).fill(password);
  await page.getByRole("button", { name: /sign in|تسجيل الدخول/i }).click();
  await page.waitForURL(/\/(dashboard|onboarding)/);
}
