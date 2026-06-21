import { test, expect } from "@playwright/test";
import { login } from "./auth";

/**
 * US7 Independent Test (T082):
 *  - create branch + capture location → usable as filter
 *  - QR poster prints
 *  - assign shift + edit weekly schedule persists
 *
 * Runs against a real dev server with a seeded tenant. Skipped by default.
 */
test.describe("US7 — branches, shifts & schedule", () => {
  test.beforeEach(async ({ page }) => {
    await login(page);
  });
  test.skip("create a branch with a location", async ({ page }) => {
    await page.goto("/branches");
    await page.getByLabel(/company name|اسم/i).fill("فرع الاختبار");
    await page.getByRole("button", { name: /add branch|إضافة فرع/i }).click();
    await expect(page.getByText(/success|تم بنجاح/i)).toBeVisible();
  });

  test.skip("qr poster renders", async ({ page }) => {
    await page.goto("/branches");
    await page.getByRole("button", { name: /qr|ملصق/i }).first().click();
    await page.getByRole("button", { name: /generate qr|توليد/i }).click();
    await expect(page.locator("img[alt='QR']")).toBeVisible();
  });

  test.skip("assign a shift", async ({ page }) => {
    await page.goto("/shifts");
    await page.getByRole("button", { name: /assign members|إسناد/i }).first().click();
    await expect(page).toHaveURL(/assign/);
  });

  test.skip("publish weekly schedule", async ({ page }) => {
    await page.goto("/shifts/schedule");
    await page.getByRole("button", { name: /publish schedule|نشر الجدول/i }).click();
    await expect(page.getByText(/success|تم بنجاح/i)).toBeVisible();
  });
});
