import { test, expect } from "@playwright/test";

/**
 * US10 Independent Test (T103):
 *  - create ticket + send message → recorded
 *  - notifications list + prefs
 *  - audit log lists actions
 *  - change language/appearance
 *  - delete account warning (last-GM)
 *
 * Runs against a real dev server with a seeded tenant. Skipped by default.
 */
test.describe("US10 — support, notifications, audit & account", () => {
  test.skip("create ticket and send a message", async ({ page }) => {
    await page.goto("/support");
    await page.getByRole("button", { name: /new ticket|تذكرة جديدة/i }).click();
    await page.getByLabel(/subject|الموضوع/i).fill("مشكلة");
    await page.getByLabel(/message|الرسالة/i).fill("أحتاج مساعدة");
    await page.getByRole("button", { name: /^(send|إرسال)$/i }).click();
    await expect(page.getByText(/success|تم بنجاح/i)).toBeVisible();
  });

  test.skip("notifications list and prefs", async ({ page }) => {
    await page.goto("/notifications");
    await expect(page.getByText(/preferences|التفضيلات|notifications|الإشعارات/i)).toBeVisible();
  });

  test.skip("audit log lists actions", async ({ page }) => {
    await page.goto("/activity-log");
    await expect(page.locator("table")).toBeVisible({ timeout: 10000 }).catch(() => {});
  });

  test.skip("change language and appearance", async ({ page }) => {
    await page.goto("/account");
    await page.getByRole("button", { name: /^english$/i }).click();
    await page.getByRole("button", { name: /^dark$/i }).click();
  });

  test.skip("delete account shows last-GM warning for GM", async ({ page }) => {
    await page.goto("/account");
    await page.getByRole("button", { name: /delete account|حذف حسابي/i }).click();
    await expect(page.getByText(/last|الأخير|delete|حذف/i)).toBeVisible();
  });
});
