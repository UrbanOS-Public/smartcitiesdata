# Properties

Properties provides a series of macros for accessing
application configuration (properties) within your modules.

Properties is written  to require that each module has its
own configuration block in the umbrella top-level `releases.exs`
file. This ensures that runtime configuration is testable.

It exposes two macros, `get_config_value/2` which gets the
value assigned to the configuration key as well as `getter/2`
which creates a getter function, named for the supplied key,
you can call within the body of the module to return the
current value assigned to that key.

==> it is important to note that `get_config_value/2` is <==
==> only available at compile time and should be avoided <==
==> in favor of `getter/2` whenever possible             <==


Both macros allow you to specify default values and whether
or not the requested key should be required and handles either
scenario accordingly.

## Usage

```elixir
  defmodule Example do
    use Properties, otp_app: :example_service

    @app_name get_config_value(:app_name, required: true)

    getter(:dep_config, required: true)

    ...

    def do_something() do
      dep_config()
      |> start_service(@app_name)
      |> profit()
    end
  end
```

## Installation

```elixir
def deps do
  [
    {:properties, in_umbrella: true}
  ]
end
```
