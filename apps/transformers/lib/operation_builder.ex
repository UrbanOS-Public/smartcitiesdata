defmodule Transformers.OperationBuilder do
  def build("regex_extract", parameters) do
    fn payload -> Transformers.RegexExtract.transform(payload, parameters) end
  end

  def build("conversion", parameters) do
    fn payload -> Transformers.TypeConversion.transform(payload, parameters) end
  end

  def build("datetime", parameters) do
    fn payload -> Transformers.DateTime.transform(payload, parameters) end
  end

  def build(unsupported, _) do
    {:error, "Unsupported transformation type: #{unsupported}"}
  end
end
