defmodule TransitRealtime.Alert do
  @moduledoc false
  use Protobuf, syntax: :proto2

  @derive Jason.Encoder

  field(:active_period, 1, repeated: true, type: TransitRealtime.TimeRange)
  field(:informed_entity, 5, repeated: true, type: TransitRealtime.EntitySelector)

  field(
    :cause,
    6,
    optional: true,
    type: TransitRealtime.Alert.Cause,
    default: :UNKNOWN_CAUSE,
    enum: true
  )

  field(
    :effect,
    7,
    optional: true,
    type: TransitRealtime.Alert.Effect,
    default: :UNKNOWN_EFFECT,
    enum: true
  )

  field(:url, 8, optional: true, type: TransitRealtime.TranslatedString)
  field(:header_text, 10, optional: true, type: TransitRealtime.TranslatedString)
  field(:description_text, 11, optional: true, type: TransitRealtime.TranslatedString)
end
