defmodule TransitRealtime.FeedHeader do
  @moduledoc false
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
          gtfs_realtime_version: String.t(),
          incrementality: integer,
          timestamp: non_neg_integer
        }
  @derive Jason.Encoder
  defstruct [:gtfs_realtime_version, :incrementality, :timestamp]

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
