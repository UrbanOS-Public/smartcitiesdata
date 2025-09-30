defmodule TransitRealtime.TranslatedString.Translation do
  @moduledoc false
  use Protobuf, syntax: :proto2

  @derive Jason.Encoder

  field(:text, 1, required: true, type: :string)
  field(:language, 2, optional: true, type: :string)
end
