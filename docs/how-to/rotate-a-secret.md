# Rotate a secret

This guide shows how to rotate the age keys, the data key of a SOPS file, or a secret value.

Rotate when one of these occurs:

| Event | Task |
| --- | --- |
| A new computer or a new key must decrypt a SOPS file. | [Add a recipient](#add-a-recipient) |
| A recipient leaks, or goes away. | [Remove a recipient](#remove-a-recipient) |
| One year passed since the last data key rotation. | [Rotate the data key](#rotate-the-data-key) |
| One year passed since the last recovery key test. | [Test the recovery key](#test-the-recovery-key) |
| A value shows in the output of an agent. | [Rotate a leaked value](#rotate-a-leaked-value) |
| SC1 finds a value in a pull request. | [Rotate a leaked value](#rotate-a-leaked-value) |
| The scope key is lost. | [Replace a lost scope key](#replace-a-lost-scope-key) |
| The scope key and the recovery key are lost. | [Recreate the values](#recreate-the-values) |

Do the tasks of this guide by hand. Agents never do them.

## Before you start

- No agent session runs on the computer.
- The scope key of the SOPS file is on the computer, except in the tasks for a lost key.

## Add a recipient

1. Add the public key to the rule of the SOPS file in `.sops.yaml`.
2. Update the recipients of the file:

   ```bash
   sops updatekeys <file>
   ```

3. Run `mise run lint`. SC5 and SC6 must pass.
4. Commit `.sops.yaml` and the SOPS file, and open a pull request.

## Remove a recipient

Do the steps in this order.

1. Remove the public key from the rule of the SOPS file in `.sops.yaml`.
2. Update the recipients of the file:

   ```bash
   sops updatekeys <file>
   ```

3. Rotate the data key:

   ```bash
   sops rotate --in-place <file>
   ```

4. Commit `.sops.yaml` and the SOPS file, and open a pull request.
5. Rotate each value of the file at its issuer. The old ciphertext stays public in the Git history.
6. Do [Add a secret](add-a-secret.md#write-the-value) for each new value.

## Rotate the data key

1. Rotate the data key:

   ```bash
   sops rotate --in-place <file>
   ```

2. Commit the SOPS file, and open a pull request.

## Test the recovery key

1. Start the offline system that holds the recovery key.
2. Decrypt the SOPS file with the recovery key only:

   ```bash
   SOPS_AGE_KEY_FILE=<recovery-key-file> sops decrypt <file> > /dev/null
   ```

3. Make sure that the command exits with `0`.

## Rotate a leaked value

1. Rotate the value at its issuer.
2. Do [Add a secret](add-a-secret.md#write-the-value) with the new value.
3. If SC1 found the value in a pull request, remove the value from the pull request.

## Replace a lost scope key

1. Make a new scope key.
2. In the rule of the file in `.sops.yaml`, replace the public key of the lost key with the new public key.
3. Set `SOPS_AGE_KEY_FILE` to the recovery key file.
4. Do steps 2 to 6 of [Remove a recipient](#remove-a-recipient).

## Recreate the values

When the scope key and the recovery key are both lost, nobody can decrypt the SOPS file.

1. Make a new scope key and a new recovery key.
2. Put their public keys in the rule of the file in `.sops.yaml`.
3. Recreate each value at its issuer.
4. Do [Add a secret](add-a-secret.md#write-the-value) for each value.

## Related pages

- [Secrets](../reference/secrets.md#sops-file-and-keys): the keys, `.sops.yaml` and the key variables.
- [Secrets management](../explanation/secrets-management.md#why-sops-with-age): why each SOPS file has a scope key and a recovery key.
- [Add a secret](add-a-secret.md)
- [Apply the secrets](apply-the-secrets.md)
