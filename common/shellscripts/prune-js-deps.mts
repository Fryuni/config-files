#!/usr/bin/env bun
/**
 * Dependency Pruner
 *
 * Identifies unnecessary dependencies by removing them one by one and running tests.
 * If tests pass without a dependency, it remains removed from package.json.
 *
 * Features:
 * - Auto-detects package manager (npm, yarn, pnpm, bun)
 * - Finds project root by locating package.json
 * - Uses gum for interactive test command selection
 * - Preserves dependencies that are actually needed
 */

import { $ } from "bun";
import { existsSync } from "fs";
import { join, dirname } from "path";

// Find project root by looking for package.json
function findProjectRoot(): string | null {
  let currentDir = process.cwd();

  while (true) {
    const packageJsonPath = join(currentDir, "package.json");

    if (existsSync(packageJsonPath)) {
      return currentDir;
    }

    const parentDir = dirname(currentDir);

    // Reached filesystem root without finding package.json
    if (parentDir === currentDir) {
      return null;
    }

    currentDir = parentDir;
  }
}

// Detect package manager being used
async function detectPackageManager(projectRoot: string): Promise<string> {
  // Check for lock files in order of preference
  if (existsSync(join(projectRoot, "bun.lockb"))) {
    return "bun";
  }
  if (existsSync(join(projectRoot, "pnpm-lock.yaml"))) {
    return "pnpm";
  }
  if (existsSync(join(projectRoot, "yarn.lock"))) {
    return "yarn";
  }
  if (existsSync(join(projectRoot, "package-lock.json"))) {
    return "npm";
  }

  // Default to npm if no lock file found
  return "npm";
}

// Read and parse package.json
interface PackageJson {
  dependencies?: Record<string, string>;
  devDependencies?: Record<string, string>;
  scripts?: Record<string, string>;
}

async function readPackageJson(projectRoot: string): Promise<PackageJson> {
  const packageJsonPath = join(projectRoot, "package.json");
  const file = Bun.file(packageJsonPath);
  const content = await file.text();
  return JSON.parse(content);
}

// Write package.json
async function writePackageJson(
  projectRoot: string,
  packageJson: PackageJson,
): Promise<void> {
  const packageJsonPath = join(projectRoot, "package.json");
  await Bun.write(packageJsonPath, JSON.stringify(packageJson, null, 2) + "\n");
}

// Get test command from user or arguments
async function getTestCommand(
  packageJson: PackageJson,
  packageManager: string,
  args: string[],
): Promise<string[]> {
  const scripts = packageJson.scripts || {};

  let input: string;

  // If arguments provided, use them as the test command
  if (args.length > 0) {
    input = args.join(" ");
    console.log(`\n🧪 Using test command from arguments: ${input}`);
    return args;
  } else {
    // Otherwise, prompt the user
    const scriptNames = Object.keys(scripts);

    console.log("\n🧪 Enter a test command to run:");
    console.log("   - Type a script name from package.json (will be expanded)");
    console.log("   - Or type a full command to execute\n");

    if (scriptNames.length > 0) {
      console.log("Available scripts:");
      for (const [name, command] of Object.entries(scripts)) {
        console.log(`  ${name}: ${command}`);
      }
      console.log();
    }

    process.stdout.write("Test command or script name: ");

    input = await new Promise<string>((resolve) => {
      process.stdin.once("data", (data) => {
        resolve(data.toString().trim());
      });
    });
  }

  if (!input) {
    console.error("❌ No test command provided");
    process.exit(1);
  }

  // Check if input is a script name
  if (scripts[input]) {
    // Return the command to run the script using the detected package manager
    const runCommand =
      packageManager === "yarn" ? ["yarn"] : [packageManager, "run"];
    return [...runCommand, input];
  }

  // Otherwise, return the input as-is (it's a full command)
  return input.split(" ");
}

// Run package manager install
async function runInstall(
  packageManager: string,
  projectRoot: string,
): Promise<boolean> {
  try {
    const result =
      await $`cd ${projectRoot} && ${packageManager} install`.quiet();
    return result.exitCode === 0;
  } catch {
    return false;
  }
}

// Run test command
async function runTest(
  testCommand: string[],
  projectRoot: string,
): Promise<boolean> {
  try {
    const result = await $`cd ${projectRoot} && ${testCommand}`.quiet();
    return result.exitCode === 0;
  } catch {
    return false;
  }
}

// Main function
async function main(): Promise<void> {
  console.log("\n🔍 Dependency Pruner\n");

  // Find project root
  const projectRoot = findProjectRoot();

  if (!projectRoot) {
    console.error(
      "❌ Error: Not in a JavaScript project (no package.json found)",
    );
    process.exit(1);
  }

  console.log(`📁 Project root: ${projectRoot}`);

  // Change to project root
  process.chdir(projectRoot);

  // Detect package manager
  const packageManager = await detectPackageManager(projectRoot);
  console.log(`📦 Package manager: ${packageManager}`);

  // Read package.json
  const packageJson = await readPackageJson(projectRoot);

  // Get test command (from args or prompt)
  const args = process.argv.slice(2);
  const testCommand = await getTestCommand(packageJson, packageManager, args);
  console.log(`🧪 Test command: ${testCommand.join(" ")}\n`);

  // Collect all dependencies
  const dependencies = packageJson.dependencies || {};
  const devDependencies = packageJson.devDependencies || {};

  const allDeps = [
    ...Object.entries(dependencies).map(([name, version]) => ({
      name,
      version,
      isDev: false,
    })),
    ...Object.entries(devDependencies).map(([name, version]) => ({
      name,
      version,
      isDev: true,
    })),
  ];

  if (allDeps.length === 0) {
    console.log("✅ No dependencies to check");
    return;
  }

  {
    // Run install
    console.log(`  📦 Running ${packageManager} install...`);
    const installSuccess = await runInstall(packageManager, projectRoot);
    if (!installSuccess) {
      console.error(`❌ Initial install failed. Please fix your dependencies.`);
      process.exit(1);
    }

    // Run test
    console.log(`  🧪 Running tests...`);
    const testSuccess = await runTest(testCommand, projectRoot);
    if (!testSuccess) {
      console.error(`❌ Initial tests failed. Please fix your tests.`);
      process.exit(1);
    }
  }

  console.log(`🔬 Testing ${allDeps.length} dependencies...\n`);

  let removedCount = 0;
  let keptCount = 0;

  // Iterate through each dependency
  for (let i = 0; i < allDeps.length; i++) {
    const dep = allDeps[i];
    const depType = dep.isDev ? "devDependencies" : "dependencies";

    console.log(`\n[${i + 1}/${allDeps.length}] Testing: ${dep.name}`);

    // Remove dependency from package.json
    const updatedPackageJson = await readPackageJson(projectRoot);
    const depList = dep.isDev
      ? updatedPackageJson.devDependencies
      : updatedPackageJson.dependencies;

    if (!depList || !depList[dep.name]) {
      console.log(`  ⏭️  Skipping (already removed)`);
      continue;
    }

    delete depList[dep.name];
    await writePackageJson(projectRoot, updatedPackageJson);

    console.log(`  🗑️  Removed from ${depType}`);

    // Run install
    console.log(`  📦 Running ${packageManager} install...`);
    const installSuccess = await runInstall(packageManager, projectRoot);

    if (!installSuccess) {
      console.log(`  ⚠️  Install failed, restoring dependency`);
      const restoredPackageJson = await readPackageJson(projectRoot);
      if (dep.isDev) {
        restoredPackageJson.devDependencies =
          restoredPackageJson.devDependencies || {};
        restoredPackageJson.devDependencies[dep.name] = dep.version;
      } else {
        restoredPackageJson.dependencies =
          restoredPackageJson.dependencies || {};
        restoredPackageJson.dependencies[dep.name] = dep.version;
      }
      await writePackageJson(projectRoot, restoredPackageJson);
      keptCount++;
      continue;
    }

    // Run test
    console.log(`  🧪 Running tests...`);
    const testSuccess = await runTest(testCommand, projectRoot);

    if (testSuccess) {
      console.log(`  ✅ Tests passed - dependency not needed!`);
      removedCount++;
    } else {
      console.log(`  ❌ Tests failed - restoring dependency`);
      const restoredPackageJson = await readPackageJson(projectRoot);
      if (dep.isDev) {
        restoredPackageJson.devDependencies =
          restoredPackageJson.devDependencies || {};
        restoredPackageJson.devDependencies[dep.name] = dep.version;
      } else {
        restoredPackageJson.dependencies =
          restoredPackageJson.dependencies || {};
        restoredPackageJson.dependencies[dep.name] = dep.version;
      }
      await writePackageJson(projectRoot, restoredPackageJson);
      keptCount++;
    }
  }

  // Final summary
  console.log("\n" + "=".repeat(50));
  console.log("\n📊 Summary:");
  console.log(`  ✅ Removed (unnecessary): ${removedCount}`);
  console.log(`  🔒 Kept (needed): ${keptCount}`);
  console.log(`  📦 Total checked: ${allDeps.length}`);
  console.log("\n✨ Done!\n");
}

// Run main function
main().catch((error) => {
  console.error("\n❌ Error:", error instanceof Error ? error.message : error);
  process.exit(1);
});
