'use strict';

/**
 * Signs, notarizes and staples the built .dmg files.
 *
 * electron-builder signs and notarizes the .app *inside* the image, but leaves the
 * image itself alone — `dmg.sign` defaults to false. An unsigned container is fine
 * when the file is copied over USB or the local network, but a DMG downloaded from
 * the web carries a quarantine flag, and Gatekeeper assesses the container before
 * anyone reaches the app inside. So the notarized app sits behind a "cannot be
 * verified" dialog on exactly the path clients actually use.
 *
 * Turning on `dmg.sign` is not enough on its own: electron-builder notarizes during
 * afterSign, which runs before the image exists, so the DMG would be signed but not
 * notarized — still refused on macOS 10.15+. Hence a separate step, after the build.
 *
 *   npm run sign:dmg            # skips images that already validate
 *   npm run sign:dmg -- --force # re-signs regardless
 *
 * Credentials come from a notarytool keychain profile (default `permedjat-notarize`,
 * override with NOTARY_PROFILE). Create it once from a real Terminal — the write
 * does not complete from a non-interactive shell:
 *
 *   xcrun notarytool store-credentials "permedjat-notarize" \
 *     --apple-id "<apple-id-email>" --team-id "<TEAMID>"
 */

const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const ROOT = path.join(__dirname, '..');
const DIST = path.join(ROOT, 'dist');
const PROFILE = process.env.NOTARY_PROFILE || 'permedjat-notarize';
const IDENTITY = process.env.APPLE_IDENTITY || 'Developer ID Application';
const force = process.argv.includes('--force');

function run(file, args, options = {}) {
  return execFileSync(file, args, { encoding: 'utf8', ...options });
}

function isStapled(dmg) {
  try {
    run('xcrun', ['stapler', 'validate', dmg], { stdio: 'pipe' });
    return true;
  } catch {
    return false;
  }
}

if (!fs.existsSync(DIST)) {
  console.error(`no dist/ directory — run a build first`);
  process.exit(1);
}

const images = fs.readdirSync(DIST).filter((name) => name.endsWith('.dmg'));

if (images.length === 0) {
  console.error(`no .dmg files in ${DIST} — run \`npm run build:mac\` first`);
  process.exit(1);
}

for (const name of images) {
  const dmg = path.join(DIST, name);

  if (!force && isStapled(dmg)) {
    console.log(`• already notarized, skipping  ${name}`);
    continue;
  }

  console.log(`• signing        ${name}`);
  run('codesign', ['--force', '--timestamp', '--sign', IDENTITY, dmg], { stdio: 'inherit' });

  // Apple processes the upload server-side; a few minutes each is normal.
  console.log(`• notarizing     ${name}`);
  run('xcrun', ['notarytool', 'submit', dmg, '--keychain-profile', PROFILE, '--wait'], {
    stdio: 'inherit',
  });

  // Stapling attaches the ticket to the file, so it verifies without a network round-trip.
  console.log(`• stapling       ${name}`);
  run('xcrun', ['stapler', 'staple', dmg], { stdio: 'inherit' });
}

// The check that matters: what a quarantined download is assessed against.
console.log('\nGatekeeper assessment:');
for (const name of images) {
  const dmg = path.join(DIST, name);
  try {
    const output = run('spctl', ['-a', '-t', 'open', '--context', 'context:primary-signature', '-vvv', dmg], {
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    console.log(`  ✓ ${name} — ${(output.match(/source=(.*)/) || [])[1] || 'accepted'}`);
  } catch (error) {
    console.error(`  ✗ ${name} — rejected`);
    console.error(String(error.stderr || error.stdout || '').trim());
    process.exitCode = 1;
  }
}
