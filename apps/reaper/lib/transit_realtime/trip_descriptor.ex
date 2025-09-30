defmodule TransitRealtime.TripDescriptor do
  @moduledoc false
  use Protobuf, syntax: :proto2

  @derive Jason.Encoder

  field(:trip_id, 1, optional: true, type: :string)
  field(:route_id, 5, optional: true, type: :string)
  field(:direction_id, 6, optional: true, type: :uint32)
  field(:start_time, 2, optional: true, type: :string)
  field(:start_date, 3, optional: true, type: :string)

  field(
    :schedule_relationship,
    4,
    optional: true,
    type: TransitRealtime.TripDescriptor.ScheduleRelationship,
    enum: true
  )
end
