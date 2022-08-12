defmodule Transformers.OperationBuilder do
  def build("regex_extract", parameters) do
    fn payload -> Transformers.RegexExtract.transform(payload, parameters) end
  end

  def build("regex_replace", parameters) do
    fn payload -> Transformers.RegexReplace.transform(payload, parameters) end
  end

  def build("conversion", parameters) do
    fn payload -> Transformers.TypeConversion.transform(payload, parameters) end
  end

  def build("concatenation", parameters) do
    fn payload -> Transformers.Concatenation.transform(payload, parameters) end
  end

  def build("datetime", parameters) do
    fn payload -> Transformers.DateTime.transform(payload, parameters) end
  end

  def build("remove", parameters) do
    fn payload -> Transformers.Remove.transform(payload, parameters) end
  end

  def build(unsupported, _) do
    {:error, "Unsupported transformation type: #{unsupported}"}
  end

  def validate("regex_extract", parameters) do
    Transformers.RegexExtract.validate_new(parameters)
  end

  def validate("regex_replace", parameters) do
    Transformers.RegexReplace.validate_new(parameters)
  end

  def validate("conversion", parameters) do
    Transformers.TypeConversion.validate_new(parameters)
  end

  def validate("concatenation", parameters) do
    Transformers.Concatenation.validate(parameters)
  end

  def validate("datetime", parameters) do
    Transformers.DateTime.validate_new(parameters)
  end

  def validate("remove", parameters) do
    Transformers.Remove.validate_new(parameters)
  end

  def validate(unsupported, _) do
    {:error, "Unsupported transformation validation type: #{unsupported}"}
  end
end
