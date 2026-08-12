'use strict';

/**
 * Ad-hoc signs the packaged .app.
 *
 * There is no Developer ID certificate on this machine yet, so `mac.identity` is null
 * and electron-builder skips signing. macOS refuses to execute *any* unsigned arm64
 * binary, so without at least an ad-hoc signature the app cannot launch on Apple
 * Silicon at all — not even with right-click → Open.
 *
 * This is a stopgap. An ad-hoc signature still trips Gatekeeper on machines other than
 * the one that built it; proper distribution needs a Developer ID Application
 * certificate plus notarization (see README).
 *
 * Runs on `afterPack` because electron-builder skips the `afterSign` hook entirely when
 * no signing occurred.
 */

const { execFileSync } = require('node:child_process');
const path = require('node:path');

exports.default = async function adhocSign(context) {
  if (context.electronPlatformName !== 'darwin') return;

  // A real Developer ID build signs properly a moment later; stay out of its way.
  if (process.env.APPLE_IDENTITY) return;

  // The universal build packs each arch into a `-temp` directory first and merges them
  // afterwards; signing those would only be undone by the merge.
  if (context.appOutDir.endsWith('-temp')) return;

  const appPath = path.join(context.appOutDir, `${context.packager.appInfo.productFilename}.app`);

  execFileSync('codesign', ['--force', '--deep', '--sign', '-', appPath], { stdio: 'inherit' });
  console.log(`  • ad-hoc signed  file=${appPath}`);
};
