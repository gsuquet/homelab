# Sync the GitHub labels

This guide shows how to make the GitHub labels of the repository equal to `.github/labels.yml`.

Sync the labels when one of these occurs:

- a merged change adds, changes or removes a label in `.github/labels.yml`;
- a label on GitHub has a different color or description from the file.

## Before you start

- You ran `mise install`. Refer to [Install the tools](install-the-tools.md).
- Your `gh` login has write access to the issues of `gsuquet/homelab`.
- The change to `.github/labels.yml` is on `main`.

## Sync the labels

1. Show the commands that the task would run:

   ```bash
   mise run labels:sync --dry-run
   ```

2. Read the output. Make sure that each label is correct.
3. Apply the labels:

   ```bash
   mise run labels:sync
   ```

## Delete the labels that are not in the file

A deleted label goes away from each issue and PR. You cannot undo it.

1. Show the labels that the task would delete:

   ```bash
   mise run labels:sync --dry-run --prune
   ```

2. Read the list. If a label must stay, add it to `.github/labels.yml` first.
3. Apply and delete:

   ```bash
   mise run labels:sync --prune
   ```

4. Answer `y` to the question.

## Related pages

- [Mise tasks](../reference/mise-tasks.md#labelssync): the steps, the flags and the errors of `labels:sync`.
- [Work rules](../reference/how-we-work.md): the labels of the repository.
