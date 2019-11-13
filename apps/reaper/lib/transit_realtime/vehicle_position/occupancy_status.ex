defmodule TransitRealtime.VehiclePosition.OccupancyStatus do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto2

  field(:EMPTY, 0)
  field(:MANY_SEATS_AVAILABLE, 1)
  field(:FEW_SEATS_AVAILABLE, 2)
  field(:STANDING_ROOM_ONLY, 3)
  field(:CRUSHED_STANDING_ROOM_ONLY, 4)
  field(:FULL, 5)
  field(:NOT_ACCEPTING_PASSENGERS, 6)
end
