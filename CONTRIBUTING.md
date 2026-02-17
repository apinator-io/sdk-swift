# Contributing to ApinatorSDK

## Development Setup

```bash
git clone https://github.com/apinator-io/sdk-swift.git
cd sdk-swift
swift build
swift test
```

## Code Standards

- Swift 5.9+ with strict concurrency checking where applicable
- Zero external dependencies — Foundation only
- All public APIs must have doc comments
- 85%+ test coverage

## Commit Format

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(swift): add connection timeout option
fix(swift): correct reconnect delay calculation
docs(swift): update presence channel example
test(swift): add auth edge case coverage
chore(swift): update Swift tools version
```

## Pull Request Process

1. Fork the repo and create a feature branch from `main`
2. Write tests for any new functionality
3. Run the full test suite: `swift test`
4. Update documentation if you changed public APIs
5. Submit a PR with a clear description of what and why

## Architecture

See [docs/architecture.md](docs/architecture.md) for an overview of the codebase structure.

## Reporting Issues

Use [GitHub Issues](https://github.com/apinator-io/sdk-swift/issues) with the provided templates.
