Nightly Proof digest for the GitHub repository {owner}/{repo}. The repository owner is {owner}. Write all dates in the {timezone} time zone.

1. Make sure these two repositories are available in this session. Attach any that are missing with the add_repo tool, then clone them: {owner}/{repo} (the project) and jsamitt/proof-claude-plugin (the Proof harness).

2. In the proof-claude-plugin clone, read skills/proof-plan/SKILL.md and every skills/_partials file it references. Then carry out its "Nightly mode (--nightly)" section exactly, for {owner}/{repo}, using .claude/harness.json from the project repository's default branch. The digest issue is the open issue titled "Proof digest" (currently #{digest_issue}).

3. Do only what the Nightly mode section lists. Do not work on any issue, change application code, or make any change that was not ticked in the digest.

End with a one-line summary of what you posted and applied, or exactly "No activity — nothing posted."
