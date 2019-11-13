defmodule TransitRealtime.Alert.Effect do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto2

  field(:NO_SERVICE, 1)
  field(:REDUCED_SERVICE, 2)
  field(:SIGNIFICANT_DELAYS, 3)
  field(:DETOUR, 4)
  field(:ADDITIONAL_SERVICE, 5)
  field(:MODIFIED_SERVICE, 6)
  field(:OTHER_EFFECT, 7)
  field(:UNKNOWN_EFFECT, 8)
  field(:STOP_MOVED, 9)
end
