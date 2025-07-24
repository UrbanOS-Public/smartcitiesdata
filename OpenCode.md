# SmartCitiesData Development Guide

## Build Commands
- Build all: `mix compile`
- Get dependencies: `mix deps.get`
- Clean: `mix deps.clean --all && rm -f mix.lock`

## Test Commands
- Run all tests: `mix test --color`
- Run E2E tests: `mix test.e2e`
- Run single test: `mix test path/to/test_file.exs:line_number`
- Run tests with tags: `mix test --only tag`
- Run tests for a single app: `mix cmd --app app_name mix test`

## Security Checks
- Andi security check: `mix sobelow_andi`
- Discovery API security check: `mix sobelow_discovery_api`

## Style Guidelines
- Follow standard Elixir conventions (snake_case for variables and functions)
- Module names should be CamelCase
- Use pipelines (`|>`) for transforming data through multiple functions
- Organize imports with Elixir core modules first, then third-party, then local
- Keep function bodies small and focused on a single responsibility
- Use typespecs for public functions
- Handle errors with tagged tuples (`{:ok, result}` or `{:error, reason}`)
- Validate inputs at the boundary of your application
- Document public functions with @moduledoc and @doc