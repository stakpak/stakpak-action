# Setup Stakpak Agent

A GitHub Action to install and setup the [Stakpak Agent CLI](https://github.com/stakpak/agent) in your GitHub Actions workflows.

## Features

- 🚀 **Cross-platform support**: Linux, macOS, and Windows
- 📦 **Version flexibility**: Install latest or specific version
- 🔧 **Auto-configuration**: Optional API key setup
- ⚡ **Fast installation**: Direct binary download from GitHub releases
- 🛠️ **Multiple architectures**: x86_64 and ARM64 support
- 📦 **Smart caching**: Automatically cache binaries for faster subsequent runs

## Usage

### Basic Usage

```yaml
steps:
  - uses: actions/checkout@v4

  - name: Setup Stakpak CLI
    uses: stakpak/agent@v1
    with:
      api_key: ${{ secrets.STAKPAK_API_KEY }}

  - name: Run Stakpak
    run: stakpak version
```

### Run Stakpak Agent with Prompt

```yaml
steps:
  - uses: actions/checkout@v4

  - name: Setup and Run Stakpak Agent
    uses: stakpak/agent@v1
    with:
      api_key: ${{ secrets.STAKPAK_API_KEY }}
      prompt: "Analyze this repository for security vulnerabilities and generate a report"
```

### Install Specific Version

```yaml
steps:
  - name: Setup Stakpak Agent
    uses: stakpak/agent@v1
    with:
      version: "v0.1.118"
      api_key: ${{ secrets.STAKPAK_API_KEY }}
```

### Install Only (No API Key Configuration)

```yaml
steps:
  - name: Setup Stakpak Agent
    uses: stakpak/agent@v1
    with:
      install_only: "true"
```

### Advanced Prompt Configuration

```yaml
steps:
  - uses: actions/checkout@v4

  - name: Run Stakpak Agent
    uses: stakpak/agent@v1
    with:
      api_key: ${{ secrets.STAKPAK_API_KEY }}
      prompt: "Review this pull request to make sure Terraform code follows our natural language linting rules"
      max_steps: 30
      verbose: true
      workdir: "./src"
```

## Inputs

| Input           | Description                                                 | Required | Default  |
| --------------- | ----------------------------------------------------------- | -------- | -------- |
| `version`       | Version of Stakpak to install (e.g., "v0.1.118", "latest")  | No       | `latest` |
| `api_key`       | Stakpak API key for authentication                          | No       | `''`     |
| `install_only`  | Only install Stakpak CLI without configuring API key        | No       | `false`  |
| `cache_enabled` | Enable caching of Stakpak binary for faster subsequent runs | No       | `true`   |
| `prompt`        | Prompt to run Stakpak Agent with                            | No       | `''`     |
| `max_steps`     | Maximum number of steps for Stakpak Agent execution         | No       | `20`     |
| `verbose`       | Enable verbose output for Stakpak Agent execution           | No       | `true`   |
| `workdir`       | Working directory for Stakpak Agent execution               | No       | `''`     |

## Outputs

| Output      | Description                                      |
| ----------- | ------------------------------------------------ |
| `version`   | The version of Stakpak CLI that was installed    |
| `path`      | Path to the installed Stakpak CLI binary         |
| `cache_hit` | Whether the installation was restored from cache |

## Examples

### DevOps Workflow with Stakpak

```yaml
name: DevOps Analysis
on: [push, pull_request]

jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup and Run Stakpak Agent
        uses: stakpak/agent@v1
        with:
          api_key: ${{ secrets.STAKPAK_API_KEY }}
          prompt: "Analyze this repository for security vulnerabilities and generate a report"
          max_steps: 25
```

### Multi-Platform Testing

```yaml
name: Multi-Platform Test
on: [push]

jobs:
  test:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
    runs-on: ${{ matrix.os }}

    steps:
      - uses: actions/checkout@v4

      - name: Setup Stakpak Agent
        uses: stakpak/agent@v1
        with:
          api_key: ${{ secrets.STAKPAK_API_KEY }}

      - name: Test Stakpak
        run: stakpak version
```

### Using Outputs

```yaml
steps:
  - name: Setup Stakpak Agent
    id: setup-stakpak
    uses: stakpak/agent@v1
    with:
      api_key: ${{ secrets.STAKPAK_API_KEY }}

  - name: Display Installation Info
    run: |
      echo "Installed version: ${{ steps.setup-stakpak.outputs.version }}"
```

## Stakpak Agent Execution

This action can automatically run Stakpak Agent with a prompt after installation. When a `prompt` is provided, the action will execute Stakpak Agent asynchronously with the specified configuration.

### Prompt Options

- **`prompt`**: The task or question you want Stakpak Agent to execute
- **`max_steps`**: Maximum number of steps the agent can take (default: 20)
- **`verbose`**: Enable detailed output during execution (default: true)
- **`workdir`**: Working directory for the agent execution (default: repository root)

### How it Works

When you provide a prompt, the action runs:

```bash
stakpak --async --verbose --workdir <workdir> --max-steps <max_steps> "<prompt>"
```

### Example Use Cases

- **Security Analysis**: `"Analyze this repository for security vulnerabilities"`
- **Code Review**: `"Review the recent changes and suggest improvements"`
- **Documentation**: `"Generate documentation for the API endpoints"`
- **Testing**: `"Create unit tests for the new features"`

## Caching

This action automatically caches the Stakpak binary to speed up subsequent workflow runs. The cache is based on:

- Operating system (`runner.os`)
- Architecture (`runner.arch`)
- Version of Stakpak

### Cache Benefits

- **First run**: Downloads and caches the binary (~2-5 seconds)
- **Subsequent runs**: Restores from cache (~0.5-1 second)
- **Different versions**: Each version maintains its own cache

### Disable Caching

```yaml
steps:
  - name: Setup Stakpak Agent (no cache)
    uses: stakpak/agent@v1
    with:
      api_key: ${{ secrets.STAKPAK_API_KEY }}
      cache_enabled: "false"
```

### Cache Status

You can check if the binary was restored from cache using the `cache_hit` output:

```yaml
steps:
  - name: Setup Stakpak Agent
    id: setup-stakpak
    uses: stakpak/agent@v1
    with:
      api_key: ${{ secrets.STAKPAK_API_KEY }}

  - name: Check cache status
    run: |
      if [ "${{ steps.setup-stakpak.outputs.cache_hit }}" = "true" ]; then
        echo "✅ Binary restored from cache"
      else
        echo "📥 Binary downloaded and cached"
      fi
```

## API Key Setup

To use Stakpak Agent, you need an API key from [stakpak.dev](https://stakpak.dev).

1. Go to [stakpak.dev](https://stakpak.dev) and sign up for an account
2. Generate an API key
3. Add it as a secret to your GitHub repository:
   - Go to your repository settings
   - Navigate to "Secrets and variables" → "Actions"
   - Click "New repository secret"
   - Name: `STAKPAK_API_KEY`
   - Value: Your API key

## Supported Platforms

- **Linux**: x86_64
- **macOS**: x86_64, ARM64 (Apple Silicon)
- **Windows**: x86_64

## Troubleshooting

### Version Not Found

Make sure you're using a valid version tag. Check [releases](https://github.com/stakpak/agent/releases) for available versions.

## License

This action is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
