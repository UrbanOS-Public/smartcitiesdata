defmodule TransitRealtime.TripDescriptor do
  @moduledoc false
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
          trip_id: String.t(),
          route_id: String.t(),
          direction_id: non_neg_integer,
          start_time: String.t(),
          start_date: String.t(),
          schedule_relationship: integer
        }
  @derive Jason.Encoder
  defstruct [:trip_id, :route_id, :direction_id, :start_time, :start_date, :schedule_relationship]

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
