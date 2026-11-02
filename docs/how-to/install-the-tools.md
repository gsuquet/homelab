# Install the tools

This guide shows how to install the tools of the repository and its Git hooks on a computer.

Install the tools when one of these occurs:

- you clone the repository on a new computer;
- a task stops because a command is missing;
- a change to `.mise/config.toml` changes a version.

## Before you start

- You have mise. Refer to [mise: getting started](https://mise.jdx.dev/getting-started.html).
- You have Git.

## Install the tools

1. Go to the root of the repository.
2. Trust the mise configuration of the repository:

   ```bash
   mise trust
   ```

3. Install the pinned tools:

   ```bash
   mise install
   ```

## Install the Git hooks

1. Install the pre-commit hooks and the commit message hook:

   ```bash
   pre-commit install --install-hooks
   pre-commit install --hook-type commit-msg
   ```

2. Run the checks one time, to make sure that the tools work:

   ```bash
   mise run lint
   ```

## Related pages

- [Tools](../reference/tools.md): the pinned tools and their versions.
- [Mise tasks](../reference/mise-tasks.md): the tasks that use the tools.
- [Run your first local cluster](../tutorials/run-your-first-local-cluster.md)
