# Make a change

This guide shows how to take a change from a plan to a merged pull request (PR). The rules behind each step are in [Work rules](../reference/how-we-work.md).

For a small, reversible change, for example a bug fix or a change to the tooling, skip steps 1 to 3. Start at step 4, and update the docs that the change makes wrong in the same PR.

## Prepare the change

1. Write a plan in a Markdown file, outside the repository. Write the goal, the open questions, the alternatives and the steps.
2. Refine the plan until it has no open question. If only a test can answer a question, do a spike:
   1. Create a `spike/<topic>` branch.
   2. Test on `kind-local`. Refer to [Run your first local cluster](../tutorials/run-your-first-local-cluster.md).
   3. Write the finding in the plan. Do not open a PR for the spike branch.
3. Split the plan into tasks. Each task gives one PR: first the docs, then the code.

## Make each PR

4. Create the issue of the task, and add it to the project "Perso":

   ```bash
   gh issue create --repo gsuquet/homelab --title "<type>(<scope>): <task>"
   gh project item-add 2 --owner gsuquet --url <issue-url>
   ```

5. Create a branch from the current `main`:

   ```bash
   git fetch origin
   git switch -c <prefix>/<issue number>-<short-title> origin/main
   ```

6. Make the change:
   - For a docs PR, write the pages as the system will be once built. Write in the present tense, with no open questions.
   - For a code PR, write the code and the tests that make the docs true. If the code must differ from the docs, correct the docs in the same PR.
7. Run the checks, and correct each problem that they show:

   ```bash
   mise run lint
   ```

8. Make a signed commit with a [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) message, for example `fix(cilium): set the API server port`.
9. Push the branch, and open a draft PR with `Closes #<issue>` in its description:

   ```bash
   git push -u origin <branch>
   gh pr create --draft --title "<type>(<scope>): <summary>" --body-file <file>
   ```

   Fill in the sections of the PR template.

## Review and merge

10. Ask a different agent to review the PR. Give it the PR, the issue and the linked docs.
11. Fix each HIGH finding. Fix each FIX finding, or answer it with a reason in the PR. Push each fix as a new commit.
12. After a HIGH finding, ask a new agent for a second review round. Without a HIGH finding, there is no second round.
13. If the agents do not agree on a finding, add the label `state/needs-decision`, and set the Status of the item to `In review`.
14. Mark the PR ready for review.
15. A person merges the PR with a squash merge.

## Related pages

- [Work rules](../reference/how-we-work.md)
- [How we work](../explanation/how-we-work.md)
- [Mise tasks](../reference/mise-tasks.md)
