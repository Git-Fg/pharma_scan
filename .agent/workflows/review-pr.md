---
description: Review a pull request for code quality, tests, and security
---

target_pr = $ARGUMENTS

If target_pr is not provided, use the PR of the current branch.

## Parallel Review Tasks

Execute the following in parallel:

1. Check code quality and style consistency
2. Review test coverage
3. Verify documentation updates
4. Check for potential bugs or security issues

## Output

Provide a summary of findings and suggestions for improvement.
