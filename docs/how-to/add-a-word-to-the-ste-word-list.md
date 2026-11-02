# Add a word to the STE word list

This guide shows how to add a word that is not approved to the Vale check `STE.Words`, with its approved replacement.

Add a word when a review or a page shows a word that ASD-STE100 does not approve, and the check does not find it.

## Add the word

1. Open `.vale/styles/STE/Words.yml`.
2. Under `swap:`, add a line `<word>: <replacement>`. Keep the alphabetical order. Write the word in lowercase.
3. Add a row for the word to the table in [Word list](../reference/writing-rules.md#word-list). Keep the same order.
4. Run the check:

   ```bash
   mise run lint:docs
   ```

5. Correct each file that the check shows. Use the replacement, or write the sentence again.
6. Run `mise run lint:docs` again, until it passes.

The check ignores the case of the letters, so one lowercase line also finds `However` and `HOWEVER`.

## Related pages

- [Writing rules](../reference/writing-rules.md): all the rules and the full word list.
- [Mise tasks](../reference/mise-tasks.md): the `lint:docs` task.
