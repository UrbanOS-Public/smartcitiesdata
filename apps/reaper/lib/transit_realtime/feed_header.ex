defmodule TransitRealtime.FeedHeader do
  @moduledoc false
  use Protobuf, syntax: :proto2

  @derive Jason.Encoder

  field(:gtfs_realtime_version, 1, required: true, type: :string)

  field(
    :incrementality,
    2,
    optional: true,
    type: TransitRealtime.FeedHeader.Incrementality,
    default: :FULL_DATASET,
    enum: true
  )

  field(:timestamp, 3, optional: true, type: :uint64)
end
