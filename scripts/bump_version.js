#!/usr/bin/env node

/**
 * Olib Version Bumper Script
 * 
 * Usage:
 *   node scripts/bump_version.js <new_version>
 * 
 * Examples:
 *   node scripts/bump_version.js 1.0.6      # bump to 1.0.6
 *   node scripts/bump_version.js 1.1.0      # bump to 1.1.0
 *   node scripts/bump_version.js 2.0.0      # bump to 2.0.0
 * 
 * This script updates the version number in ALL of the following locations:
 *   1. pubspec.yaml          → version: x.y.z+buildNumber & msix_version
 *   2. installer.iss         → #define MyAppVersion
 *   3. settings_screen.dart  → hardcoded trailing version text
 *   4. publish_page/version.json  → remote version config
 *   5. publish_page/config.js     → download page version display
 */

const fs = require('fs');
const path = require('path');

// ─── Config ──────────────────────────────────────────────────────────────────

const ROOT = path.resolve(__dirname, '..');

const FILES = {
  pubspec:        path.join(ROOT, 'pubspec.yaml'),
  installer:      path.join(ROOT, 'installer.iss'),
  settingsScreen: path.join(ROOT, 'lib', 'screens', 'settings', 'settings_screen.dart'),
  versionJson:    path.join(ROOT, 'publish_page', 'version.json'),
  configJs:       path.join(ROOT, 'publish_page', 'config.js'),
};

// ─── Helpers ─────────────────────────────────────────────────────────────────

function readFile(filePath) {
  return fs.readFileSync(filePath, 'utf-8');
}

function writeFile(filePath, content) {
  fs.writeFileSync(filePath, content, 'utf-8');
}

/**
 * Parse a semver string "x.y.z" into { major, minor, patch }
 */
function parseSemver(version) {
  const match = version.match(/^(\d+)\.(\d+)\.(\d+)$/);
  if (!match) return null;
  return {
    major: parseInt(match[1], 10),
    minor: parseInt(match[2], 10),
    patch: parseInt(match[3], 10),
  };
}

/**
 * Compute a build number from the version: major * 10000 + minor * 100 + patch
 * This gives us a monotonically increasing integer suitable for Android versionCode.
 */
function computeBuildNumber(semver) {
  return semver.major * 10000 + semver.minor * 100 + semver.patch;
}

/**
 * Extract the current version from pubspec.yaml
 */
function getCurrentVersion() {
  const content = readFile(FILES.pubspec);
  const match = content.match(/^version:\s*(\d+\.\d+\.\d+)\+/m);
  return match ? match[1] : null;
}

// ─── Updaters ────────────────────────────────────────────────────────────────

function updatePubspec(version, buildNumber) {
  let content = readFile(FILES.pubspec);

  // Update version: x.y.z+buildNumber
  content = content.replace(
    /^(version:\s*)\d+\.\d+\.\d+\+\d+/m,
    `$1${version}+${buildNumber}`
  );

  // Update msix_version: x.y.z.0
  content = content.replace(
    /^(\s*msix_version:\s*)\d+\.\d+\.\d+\.\d+/m,
    `$1${version}.0`
  );

  writeFile(FILES.pubspec, content);
  return true;
}

function updateInstaller(version) {
  let content = readFile(FILES.installer);

  content = content.replace(
    /#define MyAppVersion ".*?"/,
    `#define MyAppVersion "${version}"`
  );

  writeFile(FILES.installer, content);
  return true;
}

function updateSettingsScreen(version) {
  let content = readFile(FILES.settingsScreen);

  // Replace the hardcoded version in the About section
  // Pattern: trailing: const Text('x.y.z'),
  content = content.replace(
    /(trailing:\s*const\s+Text\(')\d+\.\d+\.\d+('\))/,
    `$1${version}$2`
  );

  writeFile(FILES.settingsScreen, content);
  return true;
}

function updateVersionJson(version) {
  const content = readFile(FILES.versionJson);
  const json = JSON.parse(content);

  const oldVersion = json.version;
  json.version = version;

  // Update changelog version references
  if (json.changelog) {
    if (json.changelog.en) {
      json.changelog.en = json.changelog.en.replace(/v\d+\.\d+\.\d+/, `v${version}`);
    }
    if (json.changelog.zh) {
      json.changelog.zh = json.changelog.zh.replace(/v\d+\.\d+\.\d+/, `v${version}`);
    }
  }

  writeFile(FILES.versionJson, JSON.stringify(json, null, 4) + '\n');
  return true;
}

function updateConfigJs(version) {
  let content = readFile(FILES.configJs);

  // Update version: 'vx.y.z'
  content = content.replace(
    /(version:\s*')v?\d+\.\d+\.\d+(')/,
    `$1v${version}$2`
  );

  // Update direct download APK filename reference (e.g. o-lib1.0.5.apk → o-lib1.0.6.apk)
  content = content.replace(
    /(o-lib)\d+\.\d+\.\d+(\.apk)/g,
    `$1${version}$2`
  );

  writeFile(FILES.configJs, content);
  return true;
}

// ─── Main ────────────────────────────────────────────────────────────────────

function main() {
  const newVersion = process.argv[2];

  if (!newVersion) {
    const current = getCurrentVersion();
    console.log('');
    console.log('  Olib Version Bumper');
    console.log('  ───────────────────');
    console.log(`  Current version: ${current || 'unknown'}`);
    console.log('');
    console.log('  Usage: node scripts/bump_version.js <new_version>');
    console.log('  Example: node scripts/bump_version.js 1.0.6');
    console.log('');
    process.exit(1);
  }

  const semver = parseSemver(newVersion);
  if (!semver) {
    console.error(`❌ Invalid version format: "${newVersion}". Expected: x.y.z (e.g. 1.0.6)`);
    process.exit(1);
  }

  const currentVersion = getCurrentVersion();
  const buildNumber = computeBuildNumber(semver);

  console.log('');
  console.log('  🚀 Olib Version Bumper');
  console.log('  ─────────────────────');
  console.log(`  ${currentVersion || '?'} → ${newVersion} (build ${buildNumber})`);
  console.log('');

  // Verify all files exist
  for (const [name, filePath] of Object.entries(FILES)) {
    if (!fs.existsSync(filePath)) {
      console.error(`  ❌ File not found: ${filePath}`);
      process.exit(1);
    }
  }

  // Run all updates
  const updates = [
    { name: 'pubspec.yaml',                fn: () => updatePubspec(newVersion, buildNumber) },
    { name: 'installer.iss',               fn: () => updateInstaller(newVersion) },
    { name: 'settings_screen.dart',        fn: () => updateSettingsScreen(newVersion) },
    { name: 'publish_page/version.json',   fn: () => updateVersionJson(newVersion) },
    { name: 'publish_page/config.js',      fn: () => updateConfigJs(newVersion) },
  ];

  let successCount = 0;
  for (const update of updates) {
    try {
      update.fn();
      console.log(`  ✅ ${update.name}`);
      successCount++;
    } catch (err) {
      console.error(`  ❌ ${update.name}: ${err.message}`);
    }
  }

  console.log('');
  if (successCount === updates.length) {
    console.log(`  🎉 All ${successCount} files updated to v${newVersion}!`);
  } else {
    console.log(`  ⚠️  ${successCount}/${updates.length} files updated. Check errors above.`);
  }
  console.log('');
}

main();
