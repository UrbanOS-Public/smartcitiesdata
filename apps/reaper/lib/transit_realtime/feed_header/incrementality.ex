defmodule TransitRealtime.FeedHeader.Incrementality do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto2

  field(:FULL_DATASET, 0)
  field(:DIFFERENTIAL, 1)
end
