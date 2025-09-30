defmodule TransitRealtime.TimeRange do
  @moduledoc false
  use Protobuf, syntax: :proto2

  @derive Jason.Encoder

  field(:start, 1, optional: true, type: :uint64)
  field(:end, 2, optional: true, type: :uint64)
end
