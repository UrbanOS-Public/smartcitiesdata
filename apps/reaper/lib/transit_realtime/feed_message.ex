defmodule TransitRealtime.FeedMessage do
  @moduledoc false
  use Protobuf, syntax: :proto2

  @derive Jason.Encoder

  field(:header, 1, required: true, type: TransitRealtime.FeedHeader)
  field(:entity, 2, repeated: true, type: TransitRealtime.FeedEntity)
end
