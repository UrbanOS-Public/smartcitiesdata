defmodule TransitRealtime.TranslatedString do
  @moduledoc false
  use Protobuf, syntax: :proto2

  @derive Jason.Encoder

  field(:translation, 1, repeated: true, type: TransitRealtime.TranslatedString.Translation)
end
