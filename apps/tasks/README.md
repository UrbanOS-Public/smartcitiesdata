# Tasks

A collection of tasks to be used across umbrella sub-projects.

## app.version

This task writes each sub-project's mix version to your console. Run it with `mix cmd` against all or one project.

```bash
> mix cmd mix app.version
==> tasks
0.1.0
==> andi
0.3.2
```

```bash
> mix cmd --app andi mix app.version
==> andi
0.3.2
```

## Installation

Install from the umbrella project. This should only be used in the `dev` environment.

```elixir
def deps do
  [
    {:tasks, in_umbrella: true, only: :dev}
  ]
end
```
