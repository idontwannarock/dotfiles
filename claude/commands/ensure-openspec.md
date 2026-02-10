# Ensure OpenSpec

Run `ensure-openspec.sh` to make sure the OpenSpec CLI is installed and the current project is initialized.

Execute the following command:

```bash
ensure-openspec.sh
```

Then report the result to the user:

- If the script exits successfully (exit code 0): confirm that OpenSpec is ready and the user can proceed with `opsx:new` or other OpenSpec commands.
- If the script fails (non-zero exit code): show the error output and suggest how to fix it (e.g., install Node.js, check network).
