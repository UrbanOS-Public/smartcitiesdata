defmodule TransitRealtime.TimeRange do
  @moduledoc false
  use Protobuf, syntax: :proto2

  @type t :: %__MODULE__{
          start: non_neg_integer,
          end: non_neg_integer
        }
  @derive Jason.Encoder
  defstruct [:start, :end]

  field(:start, 1, optional: true, type: :uint64)
  field(:end, 2, optional: true, type: :uint64)
end
