defmodule TransitRealtime.VehiclePosition.VehicleStopStatus do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto2

  field(:INCOMING_AT, 0)
  field(:STOPPED_AT, 1)
  field(:IN_TRANSIT_TO, 2)
end
