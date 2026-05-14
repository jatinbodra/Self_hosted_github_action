# Self_hosted_github_action

One script. Any project. Zero GitHub Actions minutes.

A drop-in installer that turns any always-on Linux box (your EC2, your VPS, a Raspberry Pi sitting in a closet) into a free, persistent GitHub Actions runner. Workflows from your private repos execute on your hardware. GitHub bills nothing.

---

## What this gets you

| | GitHub-hosted runners | This kit (self-hosted) |
|---|---|---|
| Cost per minute | $0.008+ after the free quota | **$0 — always** |
| Suspended if billing fails | Yes | Never |
| Cold-start time per job | 10–30s | <1s (same machine, warm caches) |
| Setup time | Zero | ~10 minutes, one-time |
| Maintenance | None | Watch one systemd service |

## Quickstart

On the machine you want to host the runner (Ubuntu / Debian, x86_64):

```bash
git clone https://github.com/jatinbodra/Self_hosted_github_action
cd Self_hosted_github_action/scripts

# Get a registration token from:
#   GitHub → your repo → Settings → Actions → Runners → New self-hosted runner
# (One-time, expires in ~1 hour.)

./install.sh \
  --repo YOUR_ORG/YOUR_REPO \
  --token YOUR_REGISTRATION_TOKEN
```

That's it. The script:
1. Downloads the official runner binary
2. Registers it to your repo with a sensible name + labels
3. Installs it as a systemd service so it survives reboots
4. Starts it

Now in your project's `.github/workflows/*.yml`, change `runs-on: ubuntu-latest` → `runs-on: self-hosted`. Push. Watch it run.

## Two ways to use it

### A. Fully self-hosted

Every job runs on your box. Copy [`workflows/deploy-self-hosted.yml`](workflows/deploy-self-hosted.yml) into your project's `.github/workflows/` and adapt the install/build/deploy commands.

**Best for:** small projects, single-server setups, when you want the simplest possible model.

### B. Hybrid (recommended)

Lint + tests run on GitHub-hosted runners (free 3,000 min/month covers most projects). Build + deploy runs on your self-hosted box. Copy [`workflows/hybrid.yml`](workflows/hybrid.yml).

**Best for:** anything serious. You get GitHub's clean-VM gate for PR checks, but the long expensive deploy step costs nothing.

## Scripts

| Script | Purpose |
|---|---|
| `scripts/install.sh` | Install the runner. Re-running uninstalls the previous one first (idempotent). |
| `scripts/uninstall.sh` | Stop, deregister, delete the runner. |
| `scripts/status.sh` | Show service state + recent logs. |

All scripts accept `--help`.

## Multiple projects on one box

Each repo needs its own runner instance, but they can share the same box. Just install with a different `--dir` and `--name`:

```bash
./install.sh --repo me/project-a --token T1 --dir ~/runner-a --name proj-a-runner
./install.sh --repo me/project-b --token T2 --dir ~/runner-b --name proj-b-runner
```

Each installs as a separate systemd service. No conflict.

## How it works (one paragraph)

The GitHub-published `actions-runner` binary connects outbound to GitHub over HTTPS and long-polls for jobs assigned to runners with matching labels. When you push code, GitHub queues the job; your runner sees it within seconds, clones the repo, runs the workflow steps locally, streams logs back. No inbound ports. No GitHub compute used. No bill.

## Security notes

- **Only enable on private repos**, or repos where you trust every PR author. A self-hosted runner executes whatever the workflow says — including code from an attacker's PR. GitHub's hosted runners isolate per-job; yours don't.
- The runner reads workflow secrets you set in repo Settings. Treat the box like a secrets-bearing server: lock down SSH, keep the OS patched, don't `cat /etc/passwd` in a workflow `run:` block.
- The runner service runs as the user who invoked `install.sh`. Don't run it as root.

## When NOT to use this

- **Open-source repos with external contributors** → use GitHub-hosted; isolation matters.
- **No always-on server** → not worth it.
- **Sporadic CI usage well under 3,000 min/month** → free GitHub-hosted is simpler.

## License

MIT. See [LICENSE](LICENSE).

## Contributing

PRs welcome. The scripts target Ubuntu/Debian x86_64 today; adding `--platform` autodetect for macOS / ARM / Amazon Linux would be a clean PR.
