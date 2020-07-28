defmodule Properties do
  @moduledoc """
  A collection of macros to establish a sane pattern for working with application
  environments.

  ## Configuring application environment

  Configuration must be namespaced by application and module.

    config :my_app, MyApp.MyModule,
      key_name: "value"

  ## Accessing environment state

  This module defines macros for accessing environment state as configured above.
  Simple, compile-time access can be done with the `get_config_value/2` macro.

    defmodule MyApp.MyModule do
      use Properties, otp_app: :my_app
      @foo get_config_value(:key_name)
    end

  The `getter/2` macro defines a getter function for the given environment key.

    defmodule MyApp.MyModule do
      use Properties, otp_app: :my_app
      getter(:key_name)

      def foo do
        key_name()
      end
    end

  ## Access options

  Both `get_config_values/2` and `getter/2` macros can be optionally configured
  for more useful access to application environment.

  * `default` - Set a default value in case application environment field is not set.
  * `required` - Raise an exception if application environment field is not set.
  """
  defmacro __using__(opts) do
    otp_app = Keyword.fetch!(opts, :otp_app)

    quote do
      import Properties

      Module.put_attribute(__MODULE__, :properties_otp_app, unquote(otp_app))
    end
  end

  defmacro get_config_value(key, opts \\ []) do
    default = Keyword.get(opts, :default, nil)
    required = Keyword.get(opts, :required, false)
    module = __CALLER__.module

    case required do
      true ->
        quote do
          Application.get_env(@properties_otp_app, unquote(module), [])
          |> Keyword.fetch!(unquote(key))
        end

      false ->
        quote do
          Application.get_env(@properties_otp_app, unquote(module), [])
          |> Keyword.get(unquote(key), unquote(default))
        end
    end
  end

  defmacro getter(key, opts \\ []) do
    default = Keyword.get(opts, :default, nil)
    required = Keyword.get(opts, :required, false)
    module = __CALLER__.module

    case required do
      true ->
        quote do
          defp unquote(key)() do
            Application.get_env(@properties_otp_app, unquote(module), [])
            |> Keyword.fetch!(unquote(key))
          end
        end

      false ->
        quote do
          defp unquote(key)() do
            Application.get_env(@properties_otp_app, unquote(module), [])
            |> Keyword.get(unquote(key), unquote(default))
          end
        end
    end
  end
end
