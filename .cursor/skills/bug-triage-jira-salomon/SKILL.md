---
name: bug-triage-jira-salomon
description: >-
  Triages a Jira bug or issue for Workday Recruiting PM work by fetching the
  ticket via Jira GHE MCP, searching Salomon internal knowledge (and optionally
  Slack archives), and producing a structured summary with evidence and next
  steps. Use when the user provides a Jira key (e.g. PROJ-123), asks for bug
  triage, root cause prep, or ticket investigation with internal context.
disable-model-invocation: true
---

# Bug triage (Jira GHE + Salomon MCP)

## Before any MCP calls

1. Read the tool schema JSON for each tool you will use (under the MCP descriptors folder for this project: `mcps/<server>/tools/<tool>.json`), then call tools with arguments that match the schema.
2. Use **`call_mcp_tool`** with the correct `server` and `toolName` and the required arguments.

## MCP servers and tools

| Purpose | Server | Tool | Arguments (check JSON each time) |
|--------|--------|------|----------------------------------|
| Ticket body, fields, comments, linked PRs | `user-jira-ghe` | `getTicketDetails` | `jiraTicket` (e.g. `ABC-123`) |
| Epic scope / children (only when the key is an Epic or ticket-level flow says so) | `user-jira-ghe` | `summarizeJiraEpic` | `epicTicket` |
| Workday internal docs / knowledge | `user-salomon-internal-knowledge` | `search_workday_internal_knowledge` | `message` (required); `size` optional |
| Full page text from a URL | `user-salomon-internal-knowledge` | `get_page_content` | `url` |
| Archived Slack (only if user asks or ticket clearly needs discussion history) | `user-salomon-slack` | `slack_archive_search` | `documentType`, `query` (Elasticsearch body) |

**Salomon Jira (`user-salomon-jira`, `jira_details_tool` / `jira_search_tool`)** is a different Jira instance. Do **not** use it for the user’s primary key unless they explicitly ask to cross-check that instance.

## Workflow

1. **Parse the Jira key** from the user message (pattern like `PROJECT-123`). If missing or ambiguous, ask once for the exact key.
2. **Fetch Jira context**
   - Call `getTicketDetails` with `jiraTicket`.
   - Apply any **`displayGuide`** or formatting rules returned with the result.
   - If the issue is an **Epic** and the user wants epic-level triage (or tool output directs epic analysis), use `summarizeJiraEpic` with `epicTicket` instead of or in addition to single-ticket detail, per the tool descriptions.
3. **Build 2–4 targeted knowledge queries** from the ticket (summary, description, component, labels, error strings, product names). Prefer short, keyword-rich `message` strings for `search_workday_internal_knowledge` (minimal noise words).
4. **Deepen on URLs** — For the highest-signal links returned in Jira or search results, call `get_page_content` for at most a **small handful** of URLs (avoid bulk fetching).
5. **Slack (optional)** — Only if the user requests Slack/discussion context or the ticket clearly depends on it. Use `slack_archive_search` with a **narrow** Elasticsearch query and small `size`; `documentType` is one of `user` | `channel` | `message`.
6. **Synthesize** using the output template below. Separate **ticket claims** from **documentation-backed** statements.

## Output template

Deliver in markdown:

### Ticket snapshot

- Key, type, status, priority (if present)
- One-line summary in your own words
- Environment / tenant / version notes only if present in ticket

### Customer impact

- Who is affected and how (from ticket; flag if inferred)

### Facts vs assumptions

| Fact (from Jira or retrieved docs) | Source |
|------------------------------------|--------|
| | |

| Assumption | Why it is uncertain |
|------------|---------------------|
| | |

### Internal evidence

- Bullets tied to Salomon knowledge hits or `get_page_content` pages (quote or paraphrase briefly; cite title/URL or ticket field)

### Gaps and open questions

- What is unknown, unrepro’d, or needs eng/CS input

### Recommended next steps

- Ordered, concrete actions (do not invent owners unless named in the ticket)

## Guardrails

- Do not invent GA dates, fix versions, or customer commitments.
- If an MCP call fails, state the error and continue with what you have; list what was skipped.
- Treat internal search results as sensitive; do not paste large raw dumps—summarize and cite.
- If reproduction steps are missing, say so explicitly.
