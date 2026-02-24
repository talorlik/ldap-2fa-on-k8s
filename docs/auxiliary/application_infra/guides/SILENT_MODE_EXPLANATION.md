# SILENT_MODE Explanation

## How SILENT_MODE is Set

The `scripts/assume-github-role.sh` script automatically detects when it's running
in a non-interactive environment (like Terraform external data sources or
GitHub Actions) and enables `SILENT_MODE` to suppress all output.

### Detection Logic

`SILENT_MODE` is set to `true` if **any** of the following conditions are met:

1. **`GITHUB_ACTIONS`** environment variable is set (GitHub Actions CI/CD)
2. **`TERRAFORM_CLI_PATH`** environment variable is set (Terraform setup actions)
3. **`TF_DATA_DIR`** environment variable is set (during Terraform operations)
4. **`TERM=dumb`** (non-interactive terminal)
5. **`! -t 0`** (no TTY/stdin is not a terminal)

### Location in Code

The detection happens at the **beginning** of `scripts/assume-github-role.sh`
(lines 22-27):

```bash
SILENT_MODE=false
if [ -n "${GITHUB_ACTIONS:-}" ] || \
   [ -n "${TERRAFORM_CLI_PATH:-}" ] || \
   [ -n "${TF_DATA_DIR:-}" ] || \
   [ "${TERM:-}" = "dumb" ] || \
   [ ! -t 0 ]; then
    SILENT_MODE=true
fi
```

## What SILENT_MODE Does

When `SILENT_MODE=true`:

1. **Suppresses all output**: All `print_info()`, `print_success()`, and `print_error()`
calls output nothing
2. **Preserves existing credentials**: Doesn't unset existing AWS credentials
(needed for State Account credentials in GitHub Actions)
3. **Relaxes error handling**: Uses `set +euo pipefail` instead of `set -euo pipefail`
to prevent premature exits
4. **Uses error flags**: Sets `SCRIPT_ERROR` and `SCRIPT_ERROR_MSG` variables
instead of exiting when sourced

## Environment-Specific Behavior

### GitHub Actions

- **Detection**: `GITHUB_ACTIONS` environment variable is automatically set by GitHub
- **Behavior**:
  - Uses `DEPLOYMENT_ROLE_ARN` and `EXTERNAL_ID` from environment variables
  - No AWS Secrets Manager access required
  - All output suppressed to avoid breaking Terraform JSON

### Local Environments

- **Detection**: None of the detection conditions are met
- **Behavior**:
  - Falls back to AWS Secrets Manager for role ARNs
  - Normal output (colored messages)
  - Strict error handling (`set -euo pipefail`)

## Usage in Terraform External Data Source

The ArgoCD module's external data source sources the script:

```bash
source "$SCRIPT_PATH" "$ACCOUNT_TYPE" >"$TMP" 2>&1
```

The script:

1. Detects `TERRAFORM_CLI_PATH` or `GITHUB_ACTIONS` → enables `SILENT_MODE`
2. Suppresses all output → prevents JSON corruption
3. Sets credentials via `export` → available to the parent shell
4. Sets error flags if failed → checked by Terraform script

## Verification

To verify SILENT_MODE detection:

```bash
# In GitHub Actions (should be true)
echo "SILENT_MODE would be: $([ -n "${GITHUB_ACTIONS:-}" ] && echo "true" || echo "false")"

# In local terminal (should be false)
TERRAFORM_CLI_PATH="" TF_DATA_DIR="" TERM="xterm" ./scripts/assume-github-role.sh --help
```
