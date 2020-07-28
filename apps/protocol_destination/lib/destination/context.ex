defmodule Destination.Context do
  @moduledoc """
  Encapsulates usage-specific metadata for protocol implementations.

  ## Metadata

  `dictionary` - Dictionary for data being written to `Destination.t()`.
  `app_name` - Name of service writing to `Destination.t()`.
  `dataset_id` - Dataset identifier.
  `subset_id` - Dataset's subset identifier.
  """
  use Definition, schema: Destination.Context.V1

  @type t :: %__MODULE__{
          dictionary: Dictionary.t(),
          app_name: String.t() | atom,
          dataset_id: String.t(),
          subset_id: String.t()
        }

  defstruct [:dictionary, :app_name, :dataset_id, :subset_id]
end

defmodule Destination.Context.V1 do
  @moduledoc false
  use Definition.Schema

  def s do
    schema(%Destination.Context{
      dictionary: of_struct(Dictionary.Impl),
      app_name: spec(is_atom() or is_binary()),
      dataset_id: required_string(),
      subset_id: required_string()
    })
  end
end
