# Agent Guidelines for SmartCitiesData

## Build/Lint/Test Commands

### Build
- `mix compile` - Compile all apps in the umbrella project
- `make compile` - Alternative build command

### Lint & Format
- `mix format` - Auto-format Elixir code
- `mix format --check-formatted` - Check if code is properly formatted
- `mix credo` - Run code quality checks
- `mix sobelow` - Run security analysis (with app-specific flags)
- `mix verify` - Run format, credo, and sobelow checks

### Test
- `mix test` - Run all unit tests across umbrella apps
- `mix test path/to/specific_test.exs` - Run a single test file
- `mix test --only integration` - Run only integration tests
- `cd apps/{app_name} && mix test` - Run tests for specific app
- `cd apps/{app_name} && mix test path/to/test.exs` - Run single test in specific app

## Code Style Guidelines

### Formatting
- Use `mix format` for consistent Elixir code formatting
- Follow standard Elixir formatting conventions

### Naming Conventions
- **Modules**: PascalCase (e.g., `Andi.Application`, `DatasetStore`)
- **Functions/Atoms**: snake_case (e.g., `get_env_variable`, `:dataset`)
- **Variables**: snake_case (e.g., `kafka_endpoints`)

### Imports & Aliases
- Use aliases for long module names (e.g., `alias SmartCity.TestDataGenerator, as: TDG`)
- Group related imports together

### Error Handling
- Prefer pattern matching over explicit conditionals
- Use `case` statements for complex branching
- Return `{:ok, result}` / `{:error, reason}` tuples for functions that may fail
- Use `with` for chaining operations that may fail

### Types
- Use type specifications where beneficial
- Follow Elixir type conventions

### Testing
- Use ExUnit with `describe`/`test` blocks
- Use `@moduletag` for test configuration (e.g., `@moduletag timeout: 5000`)
- Mock dependencies with `:meck` when needed
- Use `SmartCity.TestDataGenerator` for test data

### Security
- Never log or expose secrets/keys
- Use environment variables for sensitive configuration
- Follow sobelow security recommendations