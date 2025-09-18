import { test, expect } from '@playwright/test';

const ADMIN_EMAIL = process.env.ADMIN_EMAIL;
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD;

// Helper to sign in if auth is enabled
async function signInIfNeeded(page) {
  await page.goto('/');
  // If redirected to auth, perform login when creds provided
  if (page.url().includes('/auth')) {
    if (!ADMIN_EMAIL || !ADMIN_PASSWORD) {
      test.skip(true, 'Auth required but ADMIN_EMAIL/ADMIN_PASSWORD not set');
    }
    await page.getByRole('textbox', { name: 'Email' }).fill(ADMIN_EMAIL);
    await page.getByRole('textbox', { name: /Password/ }).fill(ADMIN_PASSWORD);
    await page.getByRole('button', { name: 'Sign in' }).click();
    await expect(page.getByText("You're now logged in.")).toBeVisible({ timeout: 15000 });
  }
}

test('OpenWebUI shows hybrid models in selector', async ({ page }) => {
  await signInIfNeeded(page);

  // Open model selector
  await page.getByRole('button', { name: 'Select a model' }).click();
  const menu = page.getByRole('menu', { name: 'Select a model' });
  await expect(menu).toBeVisible();

  // Look for hybrids anywhere in the list (All/Direct)
  await expect(menu.getByRole('button', { name: 'code.hybrid' })).toBeVisible();
  await expect(menu.getByRole('button', { name: 'docs.hybrid' })).toBeVisible();
  await expect(menu.getByRole('button', { name: 'search.hybrid' })).toBeVisible();

  // Screenshot models menu
  await menu.screenshot({ path: 'e2e-artifacts/openwebui_models_hybrid_ci.png' });
});
