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

  def validate_parameters("regex_extract", parameters) do
    Transformers.RegexExtract.validate_parameters(parameters)
  end

  def validate_parameters("regex_replace", parameters) do
    Transformers.RegexReplace.validate_parameters(parameters)
  end

  def validate_parameters("conversion", parameters) do
    Transformers.TypeConversion.validate_parameters(parameters)
  end

  def validate_parameters("concatenation", parameters) do
    Transformers.Concatenation.validate_parameters(parameters)
  end

  def validate_parameters("datetime", parameters) do
    Transformers.DateTime.validate_parameters(parameters)
  end

  def validate_parameters("remove", parameters) do
    Transformers.Remove.validate_parameters(parameters)
  end

  def validate_parameters(unsupported, _) do
    {:error, "Unsupported transformation validation type: #{unsupported}"}
  end
end
