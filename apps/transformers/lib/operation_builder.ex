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

  def build("add", parameters) do
    fn payload -> Transformers.Add.transform(payload, parameters) end
  end

  def build("subtract", parameters) do
    fn payload -> Transformers.Subtract.transform(payload, parameters) end
  end

  def build("multiplication", parameters) do
    fn payload -> Transformers.Multiplication.transform(payload, parameters) end
  end

  def build("division", parameters) do
    fn payload -> Transformers.Division.transform(payload, parameters) end
  end

  def build(unsupported, _) do
    {:error, "Unsupported transformation type: #{unsupported}"}
  end

  def validate("regex_extract", parameters) do
    Transformers.RegexExtract.validate(parameters)
  end

  def validate("regex_replace", parameters) do
    Transformers.RegexReplace.validate(parameters)
  end

  def validate("conversion", parameters) do
    Transformers.TypeConversion.validate(parameters)
  end

  def validate("concatenation", parameters) do
    Transformers.Concatenation.validate(parameters)
  end

  def validate("datetime", parameters) do
    Transformers.DateTime.validate(parameters)
  end

  def validate("remove", parameters) do
    Transformers.Remove.validate(parameters)
  end

  def validate("add", parameters) do
    Transformers.Add.validate(parameters)
  end

  def validate("subtract", parameters) do
    Transformers.Subtract.validate(parameters)
  end

  def validate("multiplication", parameters) do
    Transformers.Multiplication.validate(parameters)
  end

  def validate("division", parameters) do
    Transformers.Division.validate(parameters)
  end

  def validate(unsupported, _) do
    {:error, "Unsupported transformation validation type: #{unsupported}"}
  end
end
