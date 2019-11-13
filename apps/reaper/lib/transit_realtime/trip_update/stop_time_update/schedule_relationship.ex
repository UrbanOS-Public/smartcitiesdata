defmodule TransitRealtime.TripUpdate.StopTimeUpdate.ScheduleRelationship do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto2

  field(:SCHEDULED, 0)
  field(:SKIPPED, 1)
  field(:NO_DATA, 2)
end
