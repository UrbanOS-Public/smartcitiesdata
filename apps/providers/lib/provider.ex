defmodule Providers.Provider do
  @moduledoc """
  This behavior defines a Provider. Used as the value of a key/value pair (such as in a map) it can be executed to dynamically generate the value for that key.

  A map like:
  ```
    %{
      id: "bob",
      title: %{
        provider: "Echo",
        opts: %{value: "Assistant Sales Rep"},
        version: "1"
      },
      department: %{
        name: "Sales",
        type: %{
          provider: "Echo",
          opts: %{value: "Supremely Important"},
          version: "1"
        }
      }
    }
  ```

  Would result in a map like:
  ```
    %{
      id: "bob",
      title: "Assistant Sales Rep",
      department: "Supremely Important"
    }
  ```

  ## The Provider pattern
  + Provider
    + A provider should be a submodule of Providers.
    + The name of that submodule is used to locate and execute the Provider. i.e. `provider: "Echo"` is `Providers.Echo`
  + Opts
    + A map used to pass parameters to the provider. i.e. `%{value: "Supremely Important"}`.
    + This field is __optional__. Some providers will not require input, such as `Providers.Timestamp`
  + Version
    + Allows for the versioning of providers. A major change to the functionality of a provider should be added to a new function head under a new version.
    + This should avoid the need for migrations.

  Providers provides the `Providers.Helpers.Provisioner` module for provisioning (executing within a map) providers.
  """
  @callback provide(String.t(), map()) :: any()
end
