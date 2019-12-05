defmodule TransitRealtime.TripUpdate.StopTimeEvent do
  @moduledoc false
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
          delay: integer,
          time: integer,
          uncertainty: integer
        }
  @derive Jason.Encoder
  defstruct [:delay, :time, :uncertainty]

  field(:delay, 1, optional: true, type: :int32)
  field(:time, 2, optional: true, type: :int64)
  field(:uncertainty, 3, optional: true, type: :int32)
end
