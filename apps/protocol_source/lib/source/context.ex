defmodule Source.Context do
  @moduledoc """
  Encapsulates usage-specific metadata for protocol implementations.

  ## Metadata

  `dictionary` - Required. Dictionary for data being read from `Source.t()`.
  `handler` - Required. Module used to process incoming data.
  `app_name` - Name of service reading from `Source.t()`.
  `dataset_id` - Dataset identifier.
  `subset_id` - Dataset's subset identifier.
  `decode_json` - Boolean value indicating whether JSON decoding should occur.
  `assigns` - Map used as a key/value bucket for very impl-specific metadata.
  """
  use Definition, schema: Source.Context.V1

  @type t :: %__MODULE__{
          dictionary: Dictionary.t(),
          handler: Source.Handler.impl(),
          app_name: atom | binary,
          dataset_id: String.t(),
          subset_id: String.t(),
          decode_json: boolean,
          assigns: term
        }

  defstruct dictionary: nil,
            handler: nil,
            app_name: nil,
            dataset_id: nil,
            subset_id: nil,
            decode_json: true,
            assigns: nil
end

defmodule Source.Context.V1 do
  @moduledoc false
  use Definition.Schema

  def s do
    schema(%Source.Context{
      dictionary: of_struct(Dictionary.Impl),
      handler: spec(is_atom()),
      app_name: spec(is_atom() or is_binary()),
      dataset_id: required_string(),
      subset_id: required_string(),
      decode_json: spec(is_boolean())
    })
  end
end
