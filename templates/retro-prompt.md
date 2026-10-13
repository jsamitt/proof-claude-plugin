Proof retro routine for the GitHub repository {owner}/{repo}. The repository owner is {owner}. Write all dates in the {timezone} time zone.

1. Make sure these two repositories are available in this session. Attach any that are missing with the add_repo tool, then clone them: {owner}/{repo} (the project) and jsamitt/proof-claude-plugin (the Proof harness).

2. In the proof-claude-plugin clone, read skills/proof-retro/SKILL.md and every skills/_partials file it references. Then carry out its "Unattended mode (--scheduled)" section exactly, for {owner}/{repo}, using .claude/harness.json from the project repository's default branch.

3. Do only what the Unattended mode section lists. Do not work on any issue, change application code, touch the Proof digest issue, or make any change that was not ticked in a retro issue.

End with the one-line summary that section asks for.
