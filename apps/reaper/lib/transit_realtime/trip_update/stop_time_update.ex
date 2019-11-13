defmodule TransitRealtime.TripUpdate.StopTimeUpdate do
  @moduledoc false
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
          stop_sequence: non_neg_integer,
          stop_id: String.t(),
          arrival: TransitRealtime.TripUpdate.StopTimeEvent.t(),
          departure: TransitRealtime.TripUpdate.StopTimeEvent.t(),
          schedule_relationship: integer
        }
  @derive Jason.Encoder
  defstruct [:stop_sequence, :stop_id, :arrival, :departure, :schedule_relationship]

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
