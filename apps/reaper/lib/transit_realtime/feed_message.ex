defmodule TransitRealtime.FeedMessage do
  @moduledoc false
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
          header: TransitRealtime.FeedHeader.t(),
          entity: [TransitRealtime.FeedEntity.t()]
        }
  @derive Jason.Encoder
  defstruct [:header, :entity]

  field(:header, 1, required: true, type: TransitRealtime.FeedHeader)
  field(:entity, 2, repeated: true, type: TransitRealtime.FeedEntity)
end
