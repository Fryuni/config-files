#!/usr/bin/env bun

// @ts-expect-error Bun runtime module is resolved at execution time.
import { $, spawn } from "bun";

const ORG = "croct-tech";
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


type ApiPageInfo = {
  hasNextPage: boolean;
  endCursor: string | null;
};

type ProjectSingleSelectOption = {
  id: string;
  name: string;
};

type ProjectV2SingleSelectField = {
  __typename: "ProjectV2SingleSelectField";
  id: string;
  name: string;
  options: ProjectSingleSelectOption[];
};

type ProjectIteration = {
  id: string;
  title: string;
  startDate: string;
  duration: number;
};

type ProjectV2IterationField = {
  __typename: "ProjectV2IterationField";
  id: string;
  name: string;
  configuration: {
    iterations: ProjectIteration[];
    completedIterations: ProjectIteration[];
  };
};

type ProjectFieldNode = ProjectV2SingleSelectField | ProjectV2IterationField;

type ProjectNode = {
  id: string;
  title: string;
  number: number;
  closed: boolean;
  fields: {
    nodes: Array<ProjectFieldNode | null>;
  };
};

type ListOrgProjectsResponse = {
  data?: {
    organization: {
      projectsV2: {
        pageInfo: ApiPageInfo;
        nodes: Array<ProjectNode | null>;
      };
    } | null;
  };
};


type IssueContent = {
  __typename: "Issue";
  id: string;
  number: number;
  title: string;
  url: string;
  updatedAt: string;
  state: string;
  repository: {
    nameWithOwner: string;
  };
};

type RequestedReviewerNode = {
  requestedReviewer: {
    __typename: string;
    login?: string;
    slug?: string;
  } | null;
};

type PullRequestContent = {
  __typename: "PullRequest";
  id: string;
  number: number;
  title: string;
  url: string;
  updatedAt: string;
  isDraft: boolean;
  state: string;
  author: { login: string } | null;
  reviewRequests: { nodes: Array<RequestedReviewerNode | null> };
  repository: {
    nameWithOwner: string;
  };
};
type DraftIssueContent = {
  __typename: "DraftIssue";
  title: string;
};

type ProjectItemContent = IssueContent | PullRequestContent | DraftIssueContent;

type ProjectItemNode = {
  id: string;
  content: ProjectItemContent | null;
};

type GetProjectItemsResponse = {
  data?: {
    node: {
      items: {
        pageInfo: ApiPageInfo;
        nodes: Array<ProjectItemNode | null>;
      };
    } | null;
  };
};

type IssueTimelinePullRequest = {
  __typename: "PullRequest";
  id: string;
  number: number;
  title: string;
  url: string;
  updatedAt: string;
  isDraft: boolean;
  state: string;
  author: { login: string } | null;
  reviewRequests: { nodes: Array<RequestedReviewerNode | null> };
  repository: {
    nameWithOwner: string;
  };
};

type CrossReferencedEventNode = {
  source: IssueTimelinePullRequest | { __typename: string } | null;
};

type GetIssuePRsResponse = {
  data?: {
    node: {
      timelineItems: {
        nodes: Array<CrossReferencedEventNode | null>;
      };
    } | null;
  };
};

function isIssueTimelinePullRequest(
  source: IssueTimelinePullRequest | { __typename: string } | null,
): source is IssueTimelinePullRequest {
  return source?.__typename === "PullRequest";
}


type CandidatePR = {
  id: string;
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
  sourceProject: string;
  sourceItem: "issue-link" | "project-pr";
  projectOrder: number;
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

const LIST_PROJECTS_QUERY = `
query ListOrgProjects($org: String!, $cursor: String) {
  organization(login: $org) {
    projectsV2(first: 100, after: $cursor) {
      pageInfo { hasNextPage endCursor }
      nodes {
        id
        title
        number
        closed
        fields(first: 30) {
          nodes {
            ... on ProjectV2SingleSelectField {
              __typename
              id
              name
              options { id name }
            }
            ... on ProjectV2IterationField {
              __typename
              id
              name
              configuration {
                iterations { id title startDate duration }
                completedIterations { id title startDate duration }
              }
            }
          }
        }
      }
    }
  }
}`;

const GET_PROJECT_ITEMS_QUERY = `
query GetProjectItems($projectId: ID!, $cursor: String, $filterQuery: String) {
  node(id: $projectId) {
    ... on ProjectV2 {
      items(first: 100, after: $cursor, query: $filterQuery) {
        pageInfo { hasNextPage endCursor }
        nodes {
          id
          content {
            __typename
            ... on Issue {
              id
              number
              title
              url
              updatedAt
              state
              repository { nameWithOwner }
            }
            ... on PullRequest {
              id
              number
              title
              url
              updatedAt
              isDraft
              state
              author { login }
              reviewRequests(first: 20) {
                nodes {
                  requestedReviewer {
                    __typename
                    ... on User { login }
                    ... on Team { slug }
                  }
                }
              }
              repository { nameWithOwner }
            }
            ... on DraftIssue {
              title
            }
          }
        }
      }
    }
  }
}`;

const GET_ISSUE_PRS_QUERY = `
query GetIssuePRs($issueId: ID!) {
  node(id: $issueId) {
    ... on Issue {
      timelineItems(first: 100, itemTypes: [CROSS_REFERENCED_EVENT]) {
        nodes {
          ... on CrossReferencedEvent {
            source {
              __typename
              ... on PullRequest {
                id
                number
                title
                url
                updatedAt
                isDraft
                state
                author { login }
                reviewRequests(first: 20) {
                  nodes {
                    requestedReviewer {
                      __typename
                      ... on User { login }
                      ... on Team { slug }
                    }
                  }
                }
                repository { nameWithOwner }
              }
            }
          }
        }
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


function isReviewRequestedFrom(
  pr: PullRequestContent | IssueTimelinePullRequest,
  login: string,
): boolean {
  return pr.reviewRequests.nodes.some((node) => {
    if (!node?.requestedReviewer) return false;
    if ("login" in node.requestedReviewer && node.requestedReviewer.login) {
      return node.requestedReviewer.login.toLowerCase() === login.toLowerCase();
    }
    return false;
  });
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

async function hasNewCommitsSinceLastReview(
  repoNameWithOwner: string,
  prNumber: number,
  reviewer: string,
): Promise<{ hasNew: boolean; reason: string }> {
  const parts = parseRepoIdentifier(repoNameWithOwner);
  if (!parts) {
    return { hasNew: false, reason: "malformed repo identifier" };
  }

  const reviews = await fetchReviews(parts.owner, parts.repo, prNumber);
  const lastReviewDate = getLastReviewDate(reviews, reviewer);

  if (lastReviewDate === null) {
    return { hasNew: false, reason: "never reviewed" };
  }

  const commits = await fetchCommits(parts.owner, parts.repo, prNumber);
  if (hasCommitsAfter(commits, lastReviewDate)) {
    return { hasNew: true, reason: `new commits after last review (${lastReviewDate.slice(0, 10)})` };
  }

  return { hasNew: false, reason: `already reviewed (${lastReviewDate.slice(0, 10)}), no new commits` };
}

async function listOpenProjects(org: string): Promise<ProjectNode[]> {
  const projects: ProjectNode[] = [];
  let cursor: string | undefined;

  while (true) {
    const response = await ghGraphql<ListOrgProjectsResponse>(LIST_PROJECTS_QUERY, {
      org,
      cursor,
    });

    const projectConn = response?.data?.organization?.projectsV2;
    if (!projectConn) {
      break;
    }

    for (const node of projectConn.nodes) {
      if (!node || node.closed) {
        continue;
      }
      projects.push(node);
    }

    if (!projectConn.pageInfo.hasNextPage || !projectConn.pageInfo.endCursor) {
      break;
    }

    cursor = projectConn.pageInfo.endCursor;
  }

  return projects;
}

async function listProjectItems(projectId: string, filterQuery?: string): Promise<ProjectItemNode[]> {
  const items: ProjectItemNode[] = [];
  let cursor: string | undefined;

  while (true) {
    const response = await ghGraphql<GetProjectItemsResponse>(GET_PROJECT_ITEMS_QUERY, {
      projectId,
      cursor,
      filterQuery,
    });

    const itemConn = response?.data?.node?.items;
    if (!itemConn) {
      break;
    }

    for (const node of itemConn.nodes) {
      if (node) {
        items.push(node);
      }
    }

    if (!itemConn.pageInfo.hasNextPage || !itemConn.pageInfo.endCursor) {
      break;
    }

    cursor = itemConn.pageInfo.endCursor;
  }

  return items;
}

function hasSprintField(project: ProjectNode): boolean {
  return project.fields.nodes.some(
    (f) => f?.__typename === "ProjectV2IterationField",
  );
}

function buildItemsQuery(project: ProjectNode): string | undefined {
  const reviewOptionNames = getReviewOptionNames(project);
  if (reviewOptionNames.length === 0) {
    return undefined;
  }

  const statusFilter = reviewOptionNames.map((n) => `"${n}"`).join(",");
  const parts = [`status:${statusFilter}`];

  if (hasSprintField(project)) {
    parts.push("sprint:<=@current");
  }

  return parts.join(" ");
}

async function getIssueLinkedPullRequests(issueId: string, issueLabel: string): Promise<IssueTimelinePullRequest[]> {
  const response = await ghGraphql<GetIssuePRsResponse>(GET_ISSUE_PRS_QUERY, { issueId });
  const nodes = response?.data?.node?.timelineItems.nodes ?? [];

  const prs: IssueTimelinePullRequest[] = [];
  for (const node of nodes) {
    if (!node || !node.source) {
      continue;
    }

    if (!isIssueTimelinePullRequest(node.source)) {
      continue;
    }

    if (node.source.state !== "OPEN") {
      const prLabel = `${node.source.repository.nameWithOwner}#${node.source.number}`;
      logInfo(`  ${colors.dim}skip ${prLabel} (via ${issueLabel}): state is ${node.source.state}${colors.reset}`);
      continue;
    }

    prs.push(node.source);
  }

  return prs;
}

function getReviewOptionNames(project: ProjectNode): string[] {
  const names: string[] = [];

  for (const field of project.fields.nodes) {
    if (!field || field.__typename !== "ProjectV2SingleSelectField") {
      continue;
    }

    if (!field.name.toLowerCase().includes("status")) {
      continue;
    }

    for (const option of field.options) {
      if (option.name.toLowerCase().includes("review")) {
        names.push(option.name);
      }
    }
  }

  return names;
}


async function main(): Promise<void> {
  const { dryRun } = parseArgs(runtimeArgv());

  console.log(`${colors.bold}${colors.blue}PR Review Triage${colors.reset} ${colors.dim}(${ORG})${colors.reset}`);
  logInfo(`Mode: ${dryRun ? "dry-run" : "execute"}`);

  const openProjects = await listOpenProjects(ORG);
  logInfo(`Open projects (${openProjects.length}): ${openProjects.map((p) => p.title).join(", ")}`);


  const candidatePRs: CandidatePR[] = [];
  for (const project of openProjects) {
    const query = buildItemsQuery(project);
    if (query === undefined) {
      logWarn(`Project ${project.title}: no review-like status options found, skipping.`);
      continue;
    }

    logInfo(`Scanning ${project.title} with query: ${query}`);
    const items = await listProjectItems(project.id, query);
    let itemIndex = 0;

    for (const item of items) {
      if (item.content === null || item.content.__typename === "DraftIssue") {
        continue;
      }

      const currentIndex = itemIndex;
      itemIndex += 1;

      if (item.content.__typename === "PullRequest") {
        const label = `${item.content.repository.nameWithOwner}#${item.content.number}`;
        if (item.content.state !== "OPEN") {
          logInfo(`  ${colors.dim}skip ${label}: state is ${item.content.state}${colors.reset}`);
          continue;
        }

        if (item.content.isDraft) {
          logInfo(`  ${colors.dim}skip ${label}: draft PR${colors.reset}`);
          continue;
        }

        if (!isReviewRequestedFrom(item.content, REVIEWER_LOGIN)) {
          const { hasNew, reason } = await hasNewCommitsSinceLastReview(
            item.content.repository.nameWithOwner,
            item.content.number,
            REVIEWER_LOGIN,
          );
          if (!hasNew) {
            logInfo(`  ${colors.dim}skip ${label}: review not requested, ${reason}${colors.reset}`);
            continue;
          }
          logInfo(`  ${colors.green}↻${colors.reset} ${label}: ${reason}`);
        }

        candidatePRs.push({
          id: item.content.id,
          number: item.content.number,
          title: item.content.title,
          url: item.content.url,
          updatedAt: item.content.updatedAt,
          isDraft: item.content.isDraft,
          state: item.content.state,
          author: item.content.author?.login ?? null,
          repository: item.content.repository,
          sourceProject: project.title,
          sourceItem: "project-pr",
          projectOrder: currentIndex,
        });
        continue;
      }

      if (item.content.__typename === "Issue") {
        const issueLabel = `${item.content.repository.nameWithOwner}#${item.content.number}`;
        const linkedPrs = await getIssueLinkedPullRequests(item.content.id, issueLabel);
        for (const linkedPr of linkedPrs) {
          const prLabel = `${linkedPr.repository.nameWithOwner}#${linkedPr.number}`;
          if (linkedPr.isDraft) {
            logInfo(`  ${colors.dim}skip ${prLabel} (via ${issueLabel}): draft PR${colors.reset}`);
            continue;
          }

          if (!isReviewRequestedFrom(linkedPr, REVIEWER_LOGIN)) {
            const { hasNew, reason } = await hasNewCommitsSinceLastReview(
              linkedPr.repository.nameWithOwner,
              linkedPr.number,
              REVIEWER_LOGIN,
            );
            if (!hasNew) {
              logInfo(`  ${colors.dim}skip ${prLabel} (via ${issueLabel}): review not requested, ${reason}${colors.reset}`);
              continue;
            }
            logInfo(`  ${colors.green}↻${colors.reset} ${prLabel} (via ${issueLabel}): ${reason}`);
          }

          candidatePRs.push({
            id: linkedPr.id,
            number: linkedPr.number,
            title: linkedPr.title,
            url: linkedPr.url,
            updatedAt: linkedPr.updatedAt,
            isDraft: linkedPr.isDraft,
            state: linkedPr.state,
            author: linkedPr.author?.login ?? null,
            repository: linkedPr.repository,
            sourceProject: project.title,
            sourceItem: "issue-link",
            projectOrder: currentIndex,
          });
        }
      }
    }

    logInfo(`${project.title}: ${itemIndex} items returned by server-side filter`);
  }

  const deduped = new Map<string, CandidatePR>();
  for (const pr of candidatePRs) {
    const key = `${pr.repository.nameWithOwner}#${pr.number}`;
    const existing = deduped.get(key);

    if (!existing || existing.updatedAt < pr.updatedAt) {
      deduped.set(key, pr);
    }
  }

  const uniquePRs = [...deduped.values()];
  logInfo(`Candidate PRs: ${candidatePRs.length}; deduplicated: ${uniquePRs.length}`);

  // Sort: others' PRs first (by project name alphabetically, then column order),
  // then own PRs last (same sort within)
  const reviewerLower = REVIEWER_LOGIN.toLowerCase();
  const sorted = [...deduped.values()].sort((a, b) => {
    const aIsOwn = a.author?.toLowerCase() === reviewerLower ? 1 : 0;
    const bIsOwn = b.author?.toLowerCase() === reviewerLower ? 1 : 0;
    if (aIsOwn !== bIsOwn) return aIsOwn - bIsOwn;

    const projectCmp = a.sourceProject.localeCompare(b.sourceProject);
    if (projectCmp !== 0) return projectCmp;

    return a.projectOrder - b.projectOrder;
  });

  logInfo(`PRs requiring review: ${sorted.length}`);

  if (sorted.length === 0) {
    logInfo("No PRs need review. You're all caught up! 🎉");
    logSuccess("Done.");
    return;
  }

  let lastWasOwn: boolean | null = null;
  for (const pr of sorted) {
    const isOwn = pr.author?.toLowerCase() === reviewerLower;
    if (lastWasOwn === false && isOwn) {
      console.log(`\n${colors.dim}── Your PRs ──${colors.reset}`);
    }
    lastWasOwn = isOwn;

    const authorTag = isOwn ? `${colors.dim}(yours)${colors.reset}` : `${colors.dim}by ${pr.author ?? "unknown"}${colors.reset}`;
    const command = `or --repo ${pr.repository.nameWithOwner} --pr ${pr.number}`;
    console.log(`${colors.cyan}${pr.sourceProject}${colors.reset} ${pr.url} ${authorTag}`);

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
