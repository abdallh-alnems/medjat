'use strict';

/**
 * Builds build/icon.icns (macOS) and build/icon.ico (Windows) from the shared
 * brand master used by the Flutter apps. Uses sips + iconutil, so it runs on macOS.
 *
 *   node scripts/make-icons.js
 */

const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const ROOT = path.join(__dirname, '..');
const SOURCE = path.join(ROOT, '..', 'permedjat_central', 'branding', 'icon_master.png');
const BUILD = path.join(ROOT, 'build');

if (!fs.existsSync(SOURCE)) {
  console.error(`icon master not found: ${SOURCE}`);
  process.exit(1);
}

fs.mkdirSync(BUILD, { recursive: true });

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'permedjat-icons-'));

function resize(size, destination) {
  execFileSync('sips', ['-z', String(size), String(size), SOURCE, '--out', destination], {
    stdio: 'ignore',
  });
  return destination;
}

// ---------------------------------------------------------------- macOS .icns

const iconset = path.join(tmp, 'icon.iconset');
fs.mkdirSync(iconset);

for (const [size, name] of [
  [16, 'icon_16x16.png'],
  [32, 'icon_16x16@2x.png'],
  [32, 'icon_32x32.png'],
  [64, 'icon_32x32@2x.png'],
  [128, 'icon_128x128.png'],
  [256, 'icon_128x128@2x.png'],
  [256, 'icon_256x256.png'],
  [512, 'icon_256x256@2x.png'],
  [512, 'icon_512x512.png'],
  [1024, 'icon_512x512@2x.png'],
]) {
  resize(size, path.join(iconset, name));
}

execFileSync('iconutil', ['-c', 'icns', iconset, '-o', path.join(BUILD, 'icon.icns')]);

// ---------------------------------------------------------------- Windows .ico

// An .ico is a small directory followed by the images themselves; PNG payloads are
// valid entries from Vista onwards, so the resized files go in untouched.
const ICO_SIZES = [16, 24, 32, 48, 64, 128, 256];
const images = ICO_SIZES.map((size) => ({
  size,
  data: fs.readFileSync(resize(size, path.join(tmp, `ico-${size}.png`))),
}));

const header = Buffer.alloc(6);
header.writeUInt16LE(0, 0); // reserved
header.writeUInt16LE(1, 2); // type: icon
header.writeUInt16LE(images.length, 4);

let offset = 6 + images.length * 16;
const entries = [];
for (const image of images) {
  const entry = Buffer.alloc(16);
  entry.writeUInt8(image.size >= 256 ? 0 : image.size, 0); // 0 means 256
  entry.writeUInt8(image.size >= 256 ? 0 : image.size, 1);
  entry.writeUInt8(0, 2); // palette
  entry.writeUInt8(0, 3); // reserved
  entry.writeUInt16LE(1, 4); // colour planes
  entry.writeUInt16LE(32, 6); // bits per pixel
  entry.writeUInt32LE(image.data.length, 8);
  entry.writeUInt32LE(offset, 12);
  entries.push(entry);
  offset += image.data.length;
}

fs.writeFileSync(
  path.join(BUILD, 'icon.ico'),
  Buffer.concat([header, ...entries, ...images.map((image) => image.data)]),
);

// electron-builder falls back to this for any target without a dedicated format.
fs.copyFileSync(resize(512, path.join(tmp, 'icon-512.png')), path.join(BUILD, 'icon.png'));

fs.rmSync(tmp, { recursive: true, force: true });

console.log('wrote build/icon.icns, build/icon.ico, build/icon.png');
