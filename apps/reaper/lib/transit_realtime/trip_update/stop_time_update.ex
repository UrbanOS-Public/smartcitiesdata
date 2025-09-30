defmodule TransitRealtime.TripUpdate.StopTimeUpdate do
  @moduledoc false
  use Protobuf, syntax: :proto2

  @derive Jason.Encoder

  field(:stop_sequence, 1, optional: true, type: :uint32)
  field(:stop_id, 4, optional: true, type: :string)
  field(:arrival, 2, optional: true, type: TransitRealtime.TripUpdate.StopTimeEvent)
  field(:departure, 3, optional: true, type: TransitRealtime.TripUpdate.StopTimeEvent)

  field(
    :schedule_relationship,
    5,
    optional: true,
    type: TransitRealtime.TripUpdate.StopTimeUpdate.ScheduleRelationship,
    default: :SCHEDULED,
    enum: true
  )
end
