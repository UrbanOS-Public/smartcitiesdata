defmodule Destination.Context do
  @moduledoc """
  Encapsulates usage-specific metadata for protocol implementations.

  ## Metadata

  `app_name` - Name of service writing to `Destination.t()`.
  `dataset_id` - Dataset identifier.
  `assigns` - Map used as a key/value bucket for very impl-specific metadata.
  """
  use Definition, schema: Destination.Context.V1

  @type t :: %__MODULE__{
          app_name: String.t() | atom,
          dataset_id: String.t(),
          assigns: term
        }

  defstruct [:app_name, :dataset_id, :assigns]
end

defmodule Destination.Context.V1 do
  @moduledoc false
  use Definition.Schema

  def s do
    schema(%Destination.Context{
      app_name: spec(is_atom() or is_binary()),
      dataset_id: required_string()
    })
  end
end
