---
name: New-Brain
description: Bootstrap a new domain brain via a 5-phase guided interview. Produces a self-contained mh-<domain>-brain/ repo (structurally identical to mh-billing-brain) and a paired /<Domain>-Brain skill, ready to use. Use when a PM wants to start a brain for a new MyHeritage Product domain.
---

# New-Brain Skill

This skill bootstraps a new domain brain through a guided conversation. The output is a self-contained `mh-<domain>-brain/` repo plus a paired `/<Domain>-Brain` Claude Code skill installed locally. Both follow the exact shape of the reference implementation at `~/Claude/mh-billing-brain/`.

**Reference docs:**
- Spec: `~/Claude/mh-new-brain/docs/design-spec.md`
- Reference repo: `~/Claude/mh-billing-brain/`
- Reference brain: `~/Claude/brains/billing/`

## On every invocation

1. **Phase 0 — Pre-flight checks** (silent, before asking anything). Run the checks in the "Phase 0" section below. If any blocker is found, surface it and stop until resolved.
2. Run **Phase 1 → Phase 5** in order. Each phase has explicit exit conditions; do not advance until the previous phase is fully captured.
3. Write the bootstrap conversation to the in-progress `interview-log.md` file as it happens (not at the end).
4. After Phase 4 (scaffolding) succeeds, write the completion marker `## Bootstrap complete — <date>` to the new brain's `interview-log.md` (Phase 4 step 7).

## Hard rules

1. **Never silently overwrite.** If a new brain's paths already exist, surface the conflict and offer (a) pick a different name, (b) cancel, (c) overwrite with backup. Default is cancel.
2. **Substitution is deterministic, not creative.** All placeholder values come from PM answers in Phase 1-3 and are passed verbatim to `scripts/scaffold.sh`. Do not paraphrase or "improve" the PM's wording when filling templates.
3. **Bootstrap conversation is preserved verbatim.** Every Q/A in Phases 1-3 is written into the new brain's `interview-log.md` exactly as the PM said it. This makes the bootstrap auditable.
4. **Private GitHub repo by default.** `scaffold.sh` does `git init` + initial commit. Phase 4 then **pushes to a private GitHub repo** (`MyHeritage-<DOMAIN>-Brain` under the PM's account) unless the PM declines. The repo is **private** because brain content typically contains internal MyHeritage data. Never push to a public repo.
5. **Sandbox writes outside `~/Claude/`.** Writing to `~/.claude/skills/` is outside the default sandbox allowlist. The new brain's `install.sh` will be run as the last scaffold step; if a sandbox error occurs, tell the PM to run `cd ~/Claude/mh-<domain>-brain && ./install.sh` in their terminal manually.

## Phase 0 — Pre-flight checks

Run silently before Phase 1.

**Check 1 — In-progress bootstrap.** Look for any unfinished bootstrap log. Run:

```bash
for log in "$HOME"/Claude/mh-*-brain/brain/interview-log.md; do
  if [[ -f "$log" ]] && grep -q '^## Bootstrap —' "$log" && ! grep -q '^## Bootstrap complete' "$log"; then
    echo "UNFINISHED: $log"
  fi
done
```

If any output: read the most recent unfinished log, extract the last `### Phase N:` marker, and ask the PM:

> "I found an unfinished bootstrap from `<domain>` (last completed: Phase N). Options:
>   (a) **resume** from Phase N+1
>   (b) **restart** this domain from scratch (the old log is preserved with a `.bak.YYYYMMDD-HHMMSS` suffix)
>   (c) **discard** and start a different domain
> Which?"

If no output: proceed to Check 2.

**Check 2 — Write permissions (and create `~/Claude/` if missing).** Verify the user can write under `~/Claude/` (where new brain repos go). On a fresh PM machine, `~/Claude/` likely doesn't exist yet — create it first, then write-check:

```bash
mkdir -p "$HOME/Claude" \
  && touch "$HOME/Claude/.new-brain-write-check" \
  && rm "$HOME/Claude/.new-brain-write-check"
```

If `mkdir` fails (home directory not writable), surface the exact path + a `chmod`/permissions suggestion and stop. If `mkdir` succeeds but `touch` fails (rare — directory exists but isn't writable), same — surface the path and stop. Otherwise proceed.

Tell the PM (one-liner, only if the folder was just created): *"Created `~/Claude/` — it'll hold this brain and any future brains you bootstrap."* Don't ask permission; this is a benign empty directory.

## Phase 1 — Domain identity (≈2 min)

Ask, one question at a time. After each answer, confirm it back briefly before moving on.

1. **Domain name.** "What's the domain called? Examples: Billing, Backoffice, Site, DNA, Family Tree."
   - Capture as `DOMAIN`.
   - Derive `SLUG` (kebab-case, lowercase): replace whitespace with `-`, drop non-alphanumeric except `-`, collapse runs of `-`.
   - Derive `SKILL_NAME` as `<DOMAIN>-Brain` (preserve casing of DOMAIN).
   - **Validate** DOMAIN: reject if empty, contains path separators (`/`, `\`), or doesn't start with a letter. On reject, explain and re-ask.
   - Confirm: "Got it — `<DOMAIN>`. The brain will live at `~/Claude/mh-<SLUG>-brain/`, and you'll use `/<SKILL_NAME>` in Claude Code. Sound right?"

2. **Conflict check.** Now that `SLUG`/`SKILL_NAME` are known, check for existing paths:
   ```bash
   for p in "$HOME/Claude/mh-${SLUG}-brain" "$HOME/Claude/brains/${SLUG}" "$HOME/.claude/skills/${SKILL_NAME}"; do
     [[ -e "$p" ]] && echo "EXISTS: $p"
   done
   ```
   If any exist: tell the PM exactly which, and offer (a) pick a different name, (b) cancel, (c) overwrite with timestamped backup.

3. **Description.** "In one paragraph, how would you describe this domain to someone joining MyHeritage tomorrow?"
   - Capture as `DESCRIPTION` (single paragraph, no newlines).

4. **Audience.** "Who's the audience for this brain? (just you / your band / cross-functional PMs / the whole product org)"
   - Capture as `AUDIENCE`.

5. **Owner.** Try `git config --global user.name` first. If non-empty, ask: "Owner of this brain will be recorded as `<git name>`. Confirm or override?" If empty: "Who's the owner (your name)?"
   - Capture as `OWNER`.

## Phase 2 — Stakeholders and anchor docs (≈2 min)

1. **Stakeholders.** "Who are the key people I should know about for this domain? Names + roles, briefly."
   - Capture as a freeform list. Save to `/tmp/new-brain-stakeholders-<SLUG>.md` (the scaffolder will pick this up if substantive).
   - If 3+ named stakeholders are given, treat this as a substantive `Band & Team` topic — flag it for inclusion in `brain.md` as an `interviewed` topic (Phase 4 step 6 below).
   - If empty/vague (e.g. "just me"), skip the topic — no `Band & Team` block, list stays in the interview log only.

2. **Anchor docs.** "What are the 1-3 documents you'd hand a new hire as 'read these first'? Confluence URLs, PRDs, dashboards, contracts — whatever's gospel. Title + URL per line. Leave URL blank if it's just a known doc name."
   - Capture as lines `<title>|<url-or-blank>`, written to `/tmp/new-brain-anchors-<SLUG>.txt`.

3. **Live layers (optional but recommended).** Ask three questions in sequence — any can be skipped with "skip" / "later" / empty answer. These wire the brain to live external sources so it can answer "current behavior", "in-flight work", and "what did the team say" questions on top of the curated topics.
   a. **Codebase (Layer 4).** "Does this domain have a primary code repo I should know about? Format `<owner>/<repo>` (e.g., `myhrtg/Web.mh-web`). I'll wire it up so the brain can answer current-behavior questions via `gh search code`. Skip if no relevant code repo."
   b. **Jira (Layer 5).** "Does this domain have a Jira project I should know about? Project key like `BIL`, `DNA`, `FTB`. I'll wire it up via the Atlassian MCP so the brain can answer in-flight-work questions (ticket status, sprint contents, ownership). Skip if you don't track in Jira."
   c. **Team Slack (Layer 6).** "Does this domain have a primary team Slack channel? Channel name like `#billing_only`. **One channel per brain** — this is the single channel the brain will consult when team-chatter context is relevant. Skip if no relevant Slack channel."
   - For each answer given, write to `/tmp/new-brain-layers-<SLUG>.txt` one line per layer in the form `layer4_repo=<repo>`, `layer5_project=<key>`, `layer6_channel=<#name>`. For Layer 6, also resolve the channel ID via `mcp__plugin_slack_slack__slack_search_channels` and write a second line `layer6_channel_id=<ID>`. Do not search for or attach supplementary channels — by design, each brain has exactly one Slack channel.
   - Skipped layers: do not write that layer's key.
   - The corresponding `_meta.md` blocks (`Codebase:`, `Jira:`, `Slack (team knowledge — Layer 6):`) will be written by Phase 4 step 6 below based on this file.

## Phase 3 — Topic collection (≈3-10 min, hybrid path)

Ask: "Do you have an onboarding doc, Confluence page, CSV, or any source that lists the topics in your domain? Paste it, share a URL, or tell me there isn't one."

**Fork A — Source provided.** PM pastes text or names a file/URL.
1. Extract a draft topic table: one row per topic-like heading or bullet in the source. Each row: `<name>|<one-line summary>`.
2. Show it back: "Here's what I pulled — N topics:\n```\n...table...\n```\nEdit, add, remove — tell me what to change."
3. Loop until the PM says "looks good" or equivalent.
4. **If extraction yields zero or clearly garbage results**: fall back to Fork B with: "I couldn't get a clean topic list from what you pasted. Let's do this conversationally instead — same outcome, slightly slower." Save the pasted content verbatim into the interview log either way.

**Fork B — No source.** Run three probes in sequence, capturing answers:
1. "What categories does your day-to-day work split into? Big buckets, not details."
2. "What would a new PM need to know that isn't obvious from reading the codebase or PRDs?"
3. "What does the broader org get wrong about your domain?"

From the answers, generate a draft topic table. Show it back and loop on edits the same way.

**Exit condition** (both forks): PM confirms the topic list. Write the final list to `/tmp/new-brain-topics-<SLUG>.txt` as one line per topic, format `<name>|<one-line summary>`.

## Phase 4 — Scaffolding (≈30 sec, automated)

By now you have: `DOMAIN`, `SLUG`, `SKILL_NAME`, `DESCRIPTION`, `AUDIENCE`, `OWNER`, today's date, plus three files: topics, anchors, and the bootstrap log fragment you've been writing during Phases 1-3.

Steps:

1. **Write the bootstrap log fragment.** During Phases 1-3 you've been appending Q/A to `/tmp/new-brain-bootstrap-log-<SLUG>.md`. The format:

   ```markdown
   ## Bootstrap — <YYYY-MM-DD>

   ### Phase 1: Identity
   Q: What's the domain called?
   A: <answer>
   …

   ### Phase 2: Stakeholders & anchor docs
   …

   ### Phase 3: Topic collection
   …
   ```

2. **Invoke the scaffolder.** Tell the user you're about to run the scaffolder; expect a Bash permission prompt. Run:

   ```bash
   bash ~/Claude/mh-new-brain/scripts/scaffold.sh \
     --domain "<DOMAIN>" \
     --slug "<SLUG>" \
     --skill-name "<SKILL_NAME>" \
     --description "<DESCRIPTION>" \
     --audience "<AUDIENCE>" \
     --owner "<OWNER>" \
     --bootstrap-date "$(date +%Y-%m-%d)" \
     --topics-file /tmp/new-brain-topics-<SLUG>.txt \
     --anchors-file /tmp/new-brain-anchors-<SLUG>.txt \
     --interview-log-file /tmp/new-brain-bootstrap-log-<SLUG>.md
   ```

   Expect `Scaffold complete: /Users/<user>/Claude/mh-<slug>-brain`. If the script exits non-zero, surface the message and stop — do NOT continue to step 3.

3. **Pre-flight install.sh** with the dry-run protection that mirrors the Billing pattern. Run:

   ```bash
   ls -la ~/Claude/mh-<SLUG>-brain/install.sh
   ```

   Confirm the file exists and is executable.

4. **Run the new brain's install.sh.** This deploys the per-domain skill into `~/.claude/skills/<SKILL_NAME>/` and the brain into `~/Claude/brains/<SLUG>/`. Expect a Bash permission prompt because the script writes outside the sandbox allowlist.

   ```bash
   cd ~/Claude/mh-<SLUG>-brain && ./install.sh
   ```

   Expected output:
   ```
   Copied: <…>/SKILL.md → /Users/<user>/.claude/skills/<SKILL_NAME>/SKILL.md
   Copied: <…>/brain → /Users/<user>/Claude/brains/<SLUG>
   ```

   If install fails for a permission reason: tell the PM to run `cd ~/Claude/mh-<SLUG>-brain && ./install.sh` manually in their terminal, then return here.

5. **Push the new brain to a private GitHub repo.** This is the recommended practice for every brain — off-machine backup, collaboration, and recovery story. Tell the PM:

   > "I'll push your brain to a **private** GitHub repo so it has off-machine backup and history. Default name: `MyHeritage-<DOMAIN>-Brain` under your GitHub account. OK to proceed, or want to skip?"

   If the PM agrees:
   - Confirm `gh auth status` returns OK. If not, tell the PM to run `gh auth login` and resume Phase 4 from this step.
   - Detect the GitHub owner: `gh api user --jq .login` (typically the PM's own account).
   - Create the private repo + remote + push in one shot:

     ```bash
     cd ~/Claude/mh-<SLUG>-brain && gh repo create <owner>/MyHeritage-<DOMAIN>-Brain \
       --private \
       --source . \
       --remote origin \
       --push \
       --description "<DESCRIPTION>"
     ```

   - Verify with `git -C ~/Claude/mh-<SLUG>-brain branch -vv` that `main` tracks `origin/main`.
   - Report the URL: `https://github.com/<owner>/MyHeritage-<DOMAIN>-Brain`.

   **Why private:** brain content typically includes internal MyHeritage data (revenue numbers, employee names, strategic decisions, etc.). Never push public. If `--private` fails because the org/user enforces only-public repos, abort and surface the error — do not fall through to a public push.

   If the PM declines, note it in the bootstrap log (`Skipped GitHub push at PM's request on <date>`) and continue. The PM can push later with: `cd ~/Claude/mh-<SLUG>-brain && gh repo create <owner>/MyHeritage-<DOMAIN>-Brain --private --source . --remote origin --push`.

6. **Wire up live layers (L4 / L5 / L6) from Phase 2.3.** Read `/tmp/new-brain-layers-<SLUG>.txt`. For each key present, append a matching block to the new brain's `_meta.md` (inside the front-matter area, before `## Topic Index`). Use the Edit tool; preserve any block that's already present.

   **Layer 4 (Codebase)** — if `layer4_repo=<owner>/<repo>` is set:

   ```markdown
   **Codebase:**
   - primary_repo: <owner>/<repo>
   - paths_of_interest:
     - (TBD — domain-relevant directories; update as discovered.)
   - access: requires `gh auth login` with read access to `<owner>/<repo>`.
   ```

   **Layer 5 (Jira)** — if `layer5_project=<key>` is set:

   ```markdown
   **Jira:**
   - cloud_host: myheritage.atlassian.net
   - project_key: <key>
   - default_jql_filters: (none yet — add e.g. `AND component in (...)` if generic queries become too broad)
   - access: requires the Atlassian MCP server connected in Claude Code + Atlassian Cloud auth.
   ```

   **Layer 6 (Slack — team knowledge)** — if `layer6_channel=<#name>` is set:

   ```markdown
   **Slack (team knowledge — Layer 6):**
   - channel_name: <#name>
   - channel_id: <id from layer6_channel_id>
   - type: <public|private from search result>
   - created: <date by creator from search result>
   - consultation model: **one channel per brain.** The brain consults only this channel by default. If the PM names a different channel in a question, the brain treats it as a one-off direct lookup. See SKILL.md "Domain Slack layer (Layer 6)" section.
   - access: requires the Slack MCP connected in Claude Code with workspace auth.
   ```

   **Skipped layers:** do not write a block, do not write a placeholder. The skill detects layer availability via block presence.

   Log to the bootstrap log under `### Phase 4: Live layers wired`: a one-liner per layer noting which were wired or skipped.

7. **If Phase 2 produced a substantive stakeholder list**, append a `Band & Team` topic block to the new brain's `brain.md`, status `interviewed`, with the stakeholder list as Facts. Use the Edit tool. Format:

   ```markdown
   ## Band & Team

   <!-- status: interviewed -->
   <!-- last-updated: <bootstrap-date> -->
   <!-- references: 0 -->

   ### Narrative

   <One-paragraph summary of the team, written from the PM's stakeholder answer.>

   ### Facts

   - **Product Manager:** <name if given>
   - <stakeholder list, one bullet per person, formatted with role>

   ### History & decisions

   - **<bootstrap-date>:** Captured during /New-Brain bootstrap.

   ### Open questions

   - Head count and role assignments should be refreshed periodically — who currently holds which role?

   ### References

   - (none yet)
   ```

   Then update `_meta.md`'s topic table row for `Band & Team` (if it exists) to `interviewed` status. If `Band & Team` isn't in the topic list, append it.

8. **Write the completion marker.** Append to the new brain's `interview-log.md`:

   ```markdown
   
   ## Bootstrap complete — <bootstrap-date>
   ```

9. **Confirm.** Print:

   > "✅ `<DOMAIN>` brain bootstrapped.
   > Repo: `~/Claude/mh-<SLUG>-brain/` — pushed to `https://github.com/<owner>/MyHeritage-<DOMAIN>-Brain` (private) [or 'no remote (push skipped)' if PM declined]
   > Skill: `/<SKILL_NAME>` (live; restart Claude Code if it doesn't show up)
   > Brain: `~/Claude/brains/<SLUG>/`
   > Topics seeded: N empty, M interviewed (Band & Team if applicable).
   > Live layers wired: L4 (codebase) [yes/skipped], L5 (Jira) [yes/skipped], L6 (Slack team channel) [yes/skipped].
   > Reference stubs: K (`/<SKILL_NAME> status` will list them)."

## Phase 5 — First topic handoff (optional)

Ask: "Want to do your first topic interview now? Recommended topic: `<topic>` — that's the one you sounded most animated about in Phase 2 / 3."

- **If yes**: "Restart Claude Code so it picks up the new skill, then run `/<SKILL_NAME> interview <topic>`. The new skill takes over from there — I'm done."
- **If no**: "Your brain is live. Whenever you're ready, restart Claude Code and run `/<SKILL_NAME> interview` to start your first topic. Catch you later."

## Resumability

The bootstrap conversation is written to `/tmp/new-brain-bootstrap-log-<SLUG>.md` *as it happens*, not at the end. If the session dies before Phase 4 step 7 (completion marker), the next `/New-Brain` invocation's Phase 0 detects the unfinished state and offers to resume.

When resuming:
1. Identify which phase was last completed (look for the last `### Phase N:` marker in the log).
2. Tell the PM what you have so far (briefly).
3. Pick up at the next phase, asking only the unanswered questions.
4. Phases are independent — earlier answers don't need to be re-validated.

## Failure modes & escape hatches

- **Sandbox write denied to `~/.claude/skills/`**: tell PM to run `cd ~/Claude/mh-<SLUG>-brain && ./install.sh` in their terminal; return when they confirm.
- **scaffold.sh exits 2 (conflict)**: relay the exact path; offer the three choices from Phase 1 step 2.
- **scaffold.sh exits 1 (missing template / bad input)**: investigate which file is missing; do not retry blindly.
- **PM provides a doc you can't parse in Phase 3**: fall back to Fork B; save the original paste verbatim to the log so nothing is lost.
- **PM aborts mid-Phase**: write a note to the bootstrap log explaining the abort point; leave for resume.

## Notes for Claude when running this skill

- This is a one-off scaffolder per domain. Each `/New-Brain` invocation is independent of previous ones (other than the resumability path).
- Substitution is mechanical — never rephrase the PM's wording when filling templates.
- The bootstrap log is the audit trail. Future maintainers (and future-you) read it to understand why the brain looks the way it does.
- The new brain's runtime is identical to Billing-Brain. Once the scaffold finishes, your job ends and `/<SKILL_NAME>` takes over.
