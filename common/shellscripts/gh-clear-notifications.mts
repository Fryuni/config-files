#!/usr/bin/env bun
/**
 * GitHub Notifications Manager
 * 
 * Filters and marks GitHub notifications as done based on criteria:
 * - Merged pull requests
 * - Closed issues/discussions
 * - New releases
 * - Issues/PRs with "i18n" in title
 * - Issues/PRs opened by bots
 * 
 * Rate limited to 5 requests per second
 */

import { $ } from "bun";

// Configuration
const RATE_LIMIT_PER_SECOND = 5;

const criterias: Record<string, Criteria> = {
  'i18n in title': (notification) => notification.subject.title.toLowerCase().includes("i18n"),
  'cloudflare in title': (notification) => notification.subject.title.toLowerCase().includes("cloudflare"),
  '[ci] in title': (notification) => notification.subject.title.toLowerCase().includes("[ci]"),
  '[wip] in title': (notification) => notification.subject.title.toLowerCase().includes("[wip]"),
  '[do not merge] in title': (notification) => notification.subject.title.toLowerCase().includes("[do not merge]"),
  'new release': (notification) => notification.subject.type === "Release",
  'ignored org': (notification) => {
    const ignoredOrgs = ["withstudiocms", "croct-tech"];
    const owner = notification.repository.owner.login.toLowerCase();
    return ignoredOrgs.includes(owner);
  },
  'opened by bot': (_, details) => isBot(details?.user),
  'merged PR': (_, details) => details?.merged === true,
  'draft PR': (_, details) => details?.draft === true,
  'closed issue/PR': (_, details) => details?.state === "closed",
  'closed discussion': async (notification) => {
    if (notification.subject.type !== "Discussion") {
      return false;
    }
    const state = await checkDiscussionState(notification.subject.url);
    return state === "closed";
  }
};

type Criteria = (notification: Notification, details: SubjectDetails | null) => boolean | Promise<boolean>;

// Types for GitHub API responses
interface Notification {
  id: string;
  repository: {
    full_name: string;
    owner: {
      login: string;
    };
  };
  subject: {
    title: string;
    url: string;
    type: string;
  };
  reason: string;
  updated_at: string;
}

interface SubjectDetails {
  number?: number;
  state?: string;
  merged?: boolean;
  user?: {
    login: string;
    type: string;
  };
  title?: string;
  draft?: boolean;
}

interface NotificationMatch {
  id: string;
  repository: string;
  type: string;
  title: string;
  reason: string;
  matchCriteria: string[];
}

interface FilterResult {
  match: NotificationMatch | null;
  index: number;
}

// Rate limiter class
class RateLimiter {
  private lastRequestTime: number = 0;
  private minInterval: number;
  private queue: (() => void)[] = [];
  private processing = false;

  constructor(requestsPerSecond: number) {
    this.minInterval = 1000 / requestsPerSecond;
  }

  async acquire(): Promise<void> {
    return new Promise((resolve) => {
      this.queue.push(resolve);
      if (!this.processing) {
        this.processQueue();
      }
    });
  }

  private async processQueue(): Promise<void> {
    this.processing = true;

    while (this.queue.length > 0) {
      const now = Date.now();
      const timeSinceLastRequest = now - this.lastRequestTime;

      if (timeSinceLastRequest < this.minInterval) {
        await new Promise(r => setTimeout(r, this.minInterval - timeSinceLastRequest));
      }

      const resolve = this.queue.shift();
      if (resolve) {
        this.lastRequestTime = Date.now();
        resolve();
      }
    }

    this.processing = false;
  }
}

// Create global rate limiter
const rateLimiter = new RateLimiter(RATE_LIMIT_PER_SECOND);

// Parse owner/repo/number from subject URL
function parseSubjectUrl(url: string): { owner: string; repo: string; number: number } | null {
  const match = url.match(/repos\/([^/]+)\/([^/]+)\/(?:issues|pulls)\/(\d+)$/);
  if (!match) return null;
  return {
    owner: match[1],
    repo: match[2],
    number: parseInt(match[3], 10),
  };
}

// Check if user is a bot
function isBot(user: { login: string; type: string } | undefined): boolean {
  if (!user) return false;
  return user.login.endsWith("[bot]") || user.type === "Bot";
}

// Fetch notification details
async function fetchNotifications(): Promise<Notification[]> {
  console.log("📬 Fetching notifications...");
  const { stdout, exitCode } = await $`gh api notifications --paginate`.quiet();

  if (exitCode !== 0) {
    throw new Error("Failed to fetch notifications. Make sure you're authenticated with 'gh auth login'");
  }

  return JSON.parse(stdout.toString());
}

// Fetch subject details (issue or PR) with rate limiting
async function fetchSubjectDetails(notification: Notification): Promise<SubjectDetails | null> {
  const parsed = parseSubjectUrl(notification.subject.url);
  if (!parsed) return null;

  const { owner, repo, number } = parsed;
  const type = notification.subject.type;

  await rateLimiter.acquire();

  try {
    let endpoint: string;
    if (type === "PullRequest") {
      endpoint = `repos/${owner}/${repo}/pulls/${number}`;
    } else if (type === "Issue") {
      endpoint = `repos/${owner}/${repo}/issues/${number}`;
    } else {
      return null;
    }

    const { stdout } = await $`gh api ${endpoint}`.quiet();
    return JSON.parse(stdout.toString());
  } catch (error) {
    console.error(`⚠️  Failed to fetch details for ${notification.repository.full_name} #${number}`);
    return null;
  }
}

// Check discussion state with rate limiting
async function checkDiscussionState(url: string): Promise<string> {
  const parsed = parseSubjectUrl(url);
  if (!parsed) return 'unknown';

  await rateLimiter.acquire();

  try {
    const { stdout } = await $`gh api repos/${parsed.owner}/${parsed.repo}/discussions/${parsed.number}`.quiet();
    const discussion = JSON.parse(stdout.toString());
    return discussion.state;
  } catch {
    return 'unknown';
  }
}

// Filter a single notification
async function filterNotification(notification: Notification, index: number): Promise<FilterResult> {
  const matchCriteria: string[] = [];
  const type = notification.subject.type;
  const title = notification.subject.title;
  const details = type === "Issue" || type === "PullRequest"
    ? await fetchSubjectDetails(notification)
    : null;

  for (const [criteriaName, criteriaFunc] of Object.entries(criterias)) {
    if (await criteriaFunc(notification, details)) {
      matchCriteria.push(criteriaName);
    }
  }

  // If any criteria matched, return the match
  if (matchCriteria.length > 0) {
    return {
      match: {
        id: notification.id,
        repository: notification.repository.full_name,
        type: type === "PullRequest" ? "PR" : type,
        title: title.length > 60 ? title.substring(0, 57) + "..." : title,
        reason: notification.reason,
        matchCriteria,
      },
      index,
    };
  }

  return { match: null, index };
}

// Filter notifications in parallel with rate limiting
async function filterNotifications(notifications: Notification[]): Promise<NotificationMatch[]> {
  const total = notifications.length;
  console.log(`\n🔍 Analyzing ${total} notifications in parallel (max ${RATE_LIMIT_PER_SECOND} req/sec)...\n`);

  let completed = 0;

  // Create filter promises for all notifications
  const filterPromises = notifications.map(async (notification, index) => {
    const result = await filterNotification(notification, index);

    // Update progress
    completed++;
    if (completed % 5 === 0 || completed === total) {
      process.stdout.write(`\r⏳ Progress: ${completed}/${total}`);
    }

    return result;
  });

  // Process all in parallel (rate limiter controls the actual API calls)
  const results = await Promise.all(filterPromises);

  process.stdout.write("\r" + " ".repeat(50) + "\r");

  // Collect matches
  return results
    .filter(r => r.match !== null)
    .map(r => r.match!)
    .sort((a, b) => a.repository.localeCompare(b.repository));
}

// Display results in a table
function displayTable(matches: NotificationMatch[]): void {
  if (matches.length === 0) {
    console.log("✅ No notifications match the criteria.\n");
    return;
  }

  console.log(`\n📋 Found ${matches.length} matching notifications:\n`);

  // Calculate column widths
  const repoWidth = Math.max(...matches.map(m => m.repository.length), 10);
  const typeWidth = Math.max(...matches.map(m => m.type.length), 4);
  const titleWidth = Math.min(Math.max(...matches.map(m => m.title.length), 20), 60);

  // Header
  console.log(
    "┌" + "─".repeat(repoWidth + 2) + "┬" + "─".repeat(typeWidth + 2) + "┬" + "─".repeat(titleWidth + 2) + "┬" + "─".repeat(30) + "┐"
  );
  console.log(
    "│ " + "Repository".padEnd(repoWidth) + " │ " + "Type".padEnd(typeWidth) + " │ " + "Title".padEnd(titleWidth) + " │ " + "Match Criteria".padEnd(28) + " │"
  );
  console.log(
    "├" + "─".repeat(repoWidth + 2) + "┼" + "─".repeat(typeWidth + 2) + "┼" + "─".repeat(titleWidth + 2) + "┼" + "─".repeat(30) + "┤"
  );

  // Rows
  for (const match of matches) {
    const criteria = match.matchCriteria.join(", ");
    console.log(
      "│ " + match.repository.padEnd(repoWidth) + " │ " + match.type.padEnd(typeWidth) + " │ " + match.title.padEnd(titleWidth) + " │ " + criteria.padEnd(28) + " │"
    );
  }

  console.log(
    "└" + "─".repeat(repoWidth + 2) + "┴" + "─".repeat(typeWidth + 2) + "┴" + "─".repeat(titleWidth + 2) + "┴" + "─".repeat(30) + "┘"
  );
  console.log();
}

// Ask for confirmation
async function askConfirmation(count: number): Promise<boolean> {
  const question = `❓ Mark all ${count} notifications as done? (y/N): `;
  process.stdout.write(question);

  const response = await new Promise<string>((resolve) => {
    process.stdin.once("data", (data) => {
      resolve(data.toString().trim().toLowerCase());
    });
  });

  return response === "y" || response === "yes";
}

// Mark a single notification as done with rate limiting
async function markNotificationAsDone(match: NotificationMatch, index: number, total: number): Promise<boolean> {
  await rateLimiter.acquire();

  try {
    const { exitCode } = await $`gh api -X DELETE notifications/threads/${match.id}`.quiet();
    return exitCode === 0;
  } catch {
    return false;
  }
}

// Mark notifications as done in parallel with rate limiting
async function markAsDone(matches: NotificationMatch[]): Promise<void> {
  console.log(`\n🗑️  Marking ${matches.length} notifications as done (max ${RATE_LIMIT_PER_SECOND} req/sec)...\n`);

  let completed = 0;
  let success = 0;
  let failed = 0;

  // Create mark promises for all matches
  const markPromises = matches.map(async (match, index) => {
    const result = await markNotificationAsDone(match, index, matches.length);

    // Update progress
    completed++;
    if (result) {
      success++;
    } else {
      failed++;
    }

    if (completed % 5 === 0 || completed === matches.length) {
      process.stdout.write(`\r⏳ Marking: ${completed}/${matches.length} (✅ ${success} | ❌ ${failed})`);
    }

    return result;
  });

  // Process all in parallel (rate limiter controls the actual API calls)
  await Promise.all(markPromises);

  process.stdout.write("\r" + " ".repeat(60) + "\r");
  console.log(`✅ Marked ${success} notifications as done`);
  if (failed > 0) {
    console.log(`❌ Failed to mark ${failed} notifications`);
  }
}

// Main function
async function main(): Promise<void> {
  console.log("\n🚀 GitHub Notifications Manager\n");
  console.log(`⚡ Rate limit: ${RATE_LIMIT_PER_SECOND} requests/second\n`);

  try {
    // Fetch notifications
    const notifications = await fetchNotifications();

    if (notifications.length === 0) {
      console.log("📭 No notifications to process.\n");
      return;
    }

    console.log(`Found ${notifications.length} total notifications`);

    // Filter based on criteria
    const matches = await filterNotifications(notifications);

    // Display results
    displayTable(matches);

    // If no matches, exit early
    if (matches.length === 0) {
      return;
    }

    // Ask for confirmation
    const confirmed = await askConfirmation(matches.length);

    if (confirmed) {
      await markAsDone(matches);
    } else {
      console.log("\n❌ Operation cancelled.\n");
    }

  } catch (error) {
    console.error("\n❌ Error:", error instanceof Error ? error.message : error);
    process.exit(1);
  }

  console.log("\n✨ Done!\n");
  // Force exit to avoid hanging
  process.exit(0);
}

// Run main function
main();
