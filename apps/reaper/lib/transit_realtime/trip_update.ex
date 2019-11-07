defmodule TransitRealtime.TripUpdate do
  @moduledoc false
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
          trip: TransitRealtime.TripDescriptor.t(),
          vehicle: TransitRealtime.VehicleDescriptor.t(),
          stop_time_update: [TransitRealtime.TripUpdate.StopTimeUpdate.t()],
          timestamp: non_neg_integer,
          delay: integer
        }
  @derive Jason.Encoder
  defstruct [:trip, :vehicle, :stop_time_update, :timestamp, :delay]

  field(:trip, 1, required: true, type: TransitRealtime.TripDescriptor)
  field(:vehicle, 3, optional: true, type: TransitRealtime.VehicleDescriptor)
  field(:stop_time_update, 2, repeated: true, type: TransitRealtime.TripUpdate.StopTimeUpdate)
  field(:timestamp, 4, optional: true, type: :uint64)
  field(:delay, 5, optional: true, type: :int32)
end
