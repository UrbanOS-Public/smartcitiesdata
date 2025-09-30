defmodule TransitRealtime.TripUpdate do
  @moduledoc false
  use Protobuf, syntax: :proto2

  @derive Jason.Encoder

  field(:trip, 1, required: true, type: TransitRealtime.TripDescriptor)
  field(:vehicle, 3, optional: true, type: TransitRealtime.VehicleDescriptor)
  field(:stop_time_update, 2, repeated: true, type: TransitRealtime.TripUpdate.StopTimeUpdate)
  field(:timestamp, 4, optional: true, type: :uint64)
  field(:delay, 5, optional: true, type: :int32)
end
