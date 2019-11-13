defmodule TransitRealtime.VehiclePosition.CongestionLevel do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto2

  field(:UNKNOWN_CONGESTION_LEVEL, 0)
  field(:RUNNING_SMOOTHLY, 1)
  field(:STOP_AND_GO, 2)
  field(:CONGESTION, 3)
  field(:SEVERE_CONGESTION, 4)
end
