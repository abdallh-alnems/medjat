import { test, expect } from "@playwright/test";
import { login } from "./auth";

/**
 * US9 Independent Test (T095):
 *  - edit a setting → enforced
 *  - invite admin → pending + code
 *  - customize / reset permissions
 *  - restricted admin blocked from action AND direct URL (SC-008)
 *
 * Runs against a real dev server with a seeded tenant. Skipped by default.
 */
test.describe("US9 — settings, team & permissions", () => {
  test.beforeEach(async ({ page }) => {
    await login(page);
  });

  test.skip("edit company settings", async ({ page }) => {
    await page.goto("/settings/company");
    await page.getByLabel(/company name|اسم الشركة/i).fill("شركة محدثة");
    await page.getByRole("button", { name: /^(save|حفظ)$/i }).click();
    await expect(page.getByText(/success|تم بنجاح/i)).toBeVisible();
  });

  test.skip("invite an admin shows pending + code", async ({ page }) => {
    await page.goto("/team");
    await page.getByRole("button", { name: /invite admin|دعوة مسؤول/i }).click();
    await page.getByLabel(/email|البريد/i).fill("newadmin@medjat.com");
    await page.getByRole("button", { name: /^(send|إرسال)$/i }).click();
    await expect(page.getByText(/pending|بانتظار/i)).toBeVisible();
  });

  test.skip("restricted admin is blocked from a direct URL (SC-008)", async ({
    page,
  }) => {
    await page.goto("/settings/company");
    await expect(page.getByText(/restricted|وصول محظور/i)).toBeVisible();
  });

  test.skip("customize then reset permissions", async ({ page }) => {
    await page.goto("/team");
    await page.getByRole("button", { name: /edit permissions|تعديل الصلاحيات/i }).first().click();
    await page.getByRole("button", { name: /reset|إعادة الضبط/i }).click();
    await expect(page.getByText(/success|تم بنجاح/i)).toBeVisible();
  });
});
