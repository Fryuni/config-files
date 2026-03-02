#!/usr/bin/env bun

// @ts-expect-error Bun runtime module is resolved at execution time.
import { $, spawn } from "bun";

const EXCLUDED_ORG = "croct-tech";
const REVIEWER_LOGIN = "Fryuni";

const colors = {
  reset: "\x1b[0m",
  red: "\x1b[31m",
  green: "\x1b[32m",
  yellow: "\x1b[33m",
  blue: "\x1b[34m",
  cyan: "\x1b[36m",
  bold: "\x1b[1m",
  dim: "\x1b[2m",
};

type SearchPullRequest = {
  number: number;
  title: string;
  url: string;
  updatedAt: string;
  isDraft: boolean;
  state: "OPEN" | "CLOSED" | "MERGED";
  author: { login: string } | null;
  repository: {
    nameWithOwner: string;
  };
};

type SearchResponse = {
  data?: {
    search: {
      issueCount: number;
      pageInfo: {
        hasNextPage: boolean;
        endCursor: string | null;
      };
      nodes: Array<SearchPullRequest | null>;
    };
  };
};

type PullRequestReview = {
  user: { login: string };
  state: string;
  submitted_at: string;
};

type PullRequestCommit = {
  sha: string;
  commit: {
    committer: {
      date: string;
    };
  };
};

type CandidatePR = {
  number: number;
  title: string;
  url: string;
  updatedAt: string;
  isDraft: boolean;
  state: string;
  author: string | null;
  repository: {
    nameWithOwner: string;
  };
};

const SEARCH_PRS_QUERY = `
query SearchReviewRequested($searchQuery: String!, $cursor: String) {
  search(query: $searchQuery, type: ISSUE, first: 50, after: $cursor) {
    issueCount
    pageInfo { hasNextPage endCursor }
    nodes {
      ... on PullRequest {
        number
        title
        url
        updatedAt
        isDraft
        state
        author { login }
        repository { nameWithOwner }
      }
    }
  }
}`;

function parseArgs(argv: string[]): { dryRun: boolean } {
  return { dryRun: argv.includes("--dry-run") };
}

function runtimeArgv(): string[] {
  const runtime = globalThis as { Bun?: { argv?: string[] } };
  return runtime.Bun?.argv?.slice(2) ?? [];
}

function logInfo(message: string): void {
  console.log(`${colors.cyan}i${colors.reset} ${message}`);
}

function logWarn(message: string): void {
  console.warn(`${colors.yellow}!${colors.reset} ${message}`);
}

function logError(message: string): void {
  console.error(`${colors.red}x${colors.reset} ${message}`);
}

function logSuccess(message: string): void {
  console.log(`${colors.green}✓${colors.reset} ${message}`);
}

function parseRepoIdentifier(nameWithOwner: string): { owner: string; repo: string } | null {
  const [owner, repo] = nameWithOwner.split("/");
  if (!owner || !repo) {
    return null;
  }
  return { owner, repo };
}

async function ghGraphql<T>(query: string, variables: Record<string, string | undefined>): Promise<T | null> {
  const args: string[] = ["graphql", "-f", `query=${query}`];

  for (const [key, value] of Object.entries(variables)) {
    if (typeof value === "string") {
      args.push("-f", `${key}=${value}`);
    }
  }

  try {
    return (await $`gh api ${args}`.json()) as T;
  } catch (error) {
    if (error instanceof $.ShellError) {
      const stderr = error.stderr.toString().trim();
      logWarn(`GraphQL call failed (${stderr || `exit ${error.exitCode}`})`);
      return null;
    }

    logWarn(`GraphQL call failed (${String(error)})`);
    return null;
  }
}

async function ghRest<T>(path: string): Promise<T | null> {
  try {
    return (await $`gh api ${path}`.json()) as T;
  } catch (error) {
    if (error instanceof $.ShellError) {
      const stderr = error.stderr.toString().trim();
      logWarn(`REST call failed for ${path} (${stderr || `exit ${error.exitCode}`})`);
      return null;
    }

    logWarn(`REST call failed for ${path} (${String(error)})`);
    return null;
  }
}

async function runSearch(searchQuery: string): Promise<SearchPullRequest[]> {
  const prs: SearchPullRequest[] = [];
  let cursor: string | undefined;

  while (true) {
    const response = await ghGraphql<SearchResponse>(SEARCH_PRS_QUERY, {
      searchQuery,
      cursor,
    });

    const search = response?.data?.search;
    if (!search) {
      break;
    }

    for (const node of search.nodes) {
      if (node) {
        prs.push(node);
      }
    }

    if (!search.pageInfo.hasNextPage || !search.pageInfo.endCursor) {
      break;
    }

    cursor = search.pageInfo.endCursor;
  }

  return prs;
}

async function searchPullRequests(
  reviewer: string,
  excludedOrg: string,
): Promise<SearchPullRequest[]> {
  const requestedQuery = `review-requested:${reviewer} is:open type:pr -org:${excludedOrg} -author:${reviewer}`;
  const reviewedQuery = `reviewed-by:${reviewer} is:open type:pr -org:${excludedOrg} -author:${reviewer}`;

  const [requested, reviewed] = await Promise.all([
    runSearch(requestedQuery),
    runSearch(reviewedQuery),
  ]);

  logInfo(`Review requested: ${requested.length}, previously reviewed: ${reviewed.length}`);

  const deduped = new Map<string, SearchPullRequest>();
  for (const pr of [...requested, ...reviewed]) {
    const key = `${pr.repository.nameWithOwner}#${pr.number}`;
    if (!deduped.has(key)) {
      deduped.set(key, pr);
    }
  }

  return [...deduped.values()];
}

async function fetchReviews(owner: string, repo: string, prNumber: number): Promise<PullRequestReview[]> {
  const reviews = await ghRest<PullRequestReview[]>(
    `repos/${owner}/${repo}/pulls/${prNumber}/reviews`,
  );
  return reviews ?? [];
}

async function fetchCommits(owner: string, repo: string, prNumber: number): Promise<PullRequestCommit[]> {
  const commits = await ghRest<PullRequestCommit[]>(
    `repos/${owner}/${repo}/pulls/${prNumber}/commits?per_page=100`,
  );
  return commits ?? [];
}

function getLastReviewDate(reviews: PullRequestReview[], login: string): string | null {
  let latest: string | null = null;

  for (const review of reviews) {
    if (review.user.login.toLowerCase() !== login.toLowerCase()) {
      continue;
    }

    if (latest === null || review.submitted_at > latest) {
      latest = review.submitted_at;
    }
  }

  return latest;
}

function hasCommitsAfter(commits: PullRequestCommit[], afterDate: string): boolean {
  return commits.some((c) => c.commit.committer.date > afterDate);
}

async function needsReview(
  owner: string,
  repo: string,
  prNumber: number,
  reviewer: string,
  label: string,
): Promise<{ needed: boolean; reason: string }> {
  const reviews = await fetchReviews(owner, repo, prNumber);
  const lastReviewDate = getLastReviewDate(reviews, reviewer);

  if (lastReviewDate === null) {
    return { needed: true, reason: "never reviewed" };
  }

  const commits = await fetchCommits(owner, repo, prNumber);
  if (hasCommitsAfter(commits, lastReviewDate)) {
    return { needed: true, reason: `commits after last review (${lastReviewDate.slice(0, 10)})` };
  }

  return { needed: false, reason: `already reviewed (${lastReviewDate.slice(0, 10)}), no new commits` };
}

async function main(): Promise<void> {
  const { dryRun } = parseArgs(runtimeArgv());

  console.log(`${colors.bold}${colors.blue}OSS PR Review${colors.reset} ${colors.dim}(excluding ${EXCLUDED_ORG})${colors.reset}`);
  logInfo(`Mode: ${dryRun ? "dry-run" : "execute"}`);

  const searchResults = await searchPullRequests(REVIEWER_LOGIN, EXCLUDED_ORG);
  logInfo(`Unique PRs to evaluate: ${searchResults.length}`);

  if (searchResults.length === 0) {
    logInfo("No OSS PRs need review. You're all caught up! 🎉");
    logSuccess("Done.");
    return;
  }

  const candidatePRs: CandidatePR[] = [];

  for (const pr of searchResults) {
    const label = `${pr.repository.nameWithOwner}#${pr.number}`;

    if (pr.isDraft) {
      logInfo(`  ${colors.dim}skip ${label}: draft PR${colors.reset}`);
      continue;
    }

    const parts = parseRepoIdentifier(pr.repository.nameWithOwner);
    if (!parts) {
      logWarn(`  skip ${label}: malformed repo identifier`);
      continue;
    }

    const review = await needsReview(parts.owner, parts.repo, pr.number, REVIEWER_LOGIN, label);
    if (!review.needed) {
      logInfo(`  ${colors.dim}skip ${label}: ${review.reason}${colors.reset}`);
      continue;
    }

    logInfo(`  ${colors.green}✓${colors.reset} ${label}: ${review.reason}`);
    candidatePRs.push({
      number: pr.number,
      title: pr.title,
      url: pr.url,
      updatedAt: pr.updatedAt,
      isDraft: pr.isDraft,
      state: pr.state,
      author: pr.author?.login ?? null,
      repository: pr.repository,
    });
  }

  // Sort by most recently updated first
  const sorted = candidatePRs.sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));

  logInfo(`PRs requiring review: ${sorted.length}`);

  if (sorted.length === 0) {
    logInfo("All PRs already reviewed. You're all caught up! 🎉");
    logSuccess("Done.");
    return;
  }

  for (const pr of sorted) {
    const authorTag = `${colors.dim}by ${pr.author ?? "unknown"}${colors.reset}`;
    const command = `or --repo ${pr.repository.nameWithOwner} --pr ${pr.number}`;
    console.log(`${pr.url} ${authorTag}`);

    if (dryRun) {
      console.log(`${colors.yellow}[dry-run]${colors.reset} ${command}`);
      continue;
    }

    const parts = parseRepoIdentifier(pr.repository.nameWithOwner);
    if (!parts) {
      logWarn(`Unable to open malformed repo identifier: ${pr.repository.nameWithOwner}`);
      continue;
    }

    const proc = spawn(["or", "--repo", `${parts.owner}/${parts.repo}`, "--pr", String(pr.number)], {
      stdin: "inherit",
      stdout: "inherit",
      stderr: "inherit",
    });

    const exitCode = await proc.exited;
    if (exitCode !== 0) {
      logWarn(`Failed to open ${command} (exit ${exitCode})`);
      continue;
    }

    logSuccess(`Opened ${pr.repository.nameWithOwner}#${pr.number}`);
  }

  logSuccess("Done.");
}

main().catch((error) => {
  logError(`Fatal error: ${String(error)}`);
  throw error;
});
