defmodule TransitRealtime.TripDescriptor.ScheduleRelationship do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto2

  field(:SCHEDULED, 0)
  field(:ADDED, 1)
  field(:UNSCHEDULED, 2)
  field(:CANCELED, 3)
end
