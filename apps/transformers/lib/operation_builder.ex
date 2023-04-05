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

  def build("constant", parameters) do
    fn payload -> Transformers.Constant.transform(payload, parameters) end
  end

  def build(unsupported, _) do
    {:error, "Unsupported transformation type: #{unsupported}"}
  end

  def validate(type, parameters) do
    {validateStatus, validateReason} = validate_transform(type, parameters)
    {conditionStatus, conditionReason} = validate_condition(parameters)

    case {validateStatus, conditionStatus} do
      {:ok, :ok} ->
        {:ok, validateReason}

      {:ok, :error} ->
        {:error, conditionReason}

      {:error, :ok} ->
        {:error, validateReason}

      {:error, :error} ->
        if is_binary(validateReason),
          do: {:error, conditionReason},
          else: {:error, Map.merge(conditionReason, validateReason)}
    end
  end

  defp validate_condition(parameters) do
    if Map.get(parameters, "condition") == "true" do
      Transformers.Conditions.validate(parameters)
    else
      {:ok, true}
    end
  end

  defp validate_transform("regex_extract", parameters) do
    Transformers.RegexExtract.validate(parameters)
  end

  defp validate_transform("regex_replace", parameters) do
    Transformers.RegexReplace.validate(parameters)
  end

  defp validate_transform("conversion", parameters) do
    Transformers.TypeConversion.validate(parameters)
  end

  defp validate_transform("concatenation", parameters) do
    Transformers.Concatenation.validate(parameters)
  end

  defp validate_transform("datetime", parameters) do
    Transformers.DateTime.validate(parameters)
  end

  defp validate_transform("remove", parameters) do
    Transformers.Remove.validate(parameters)
  end

  defp validate_transform("add", parameters) do
    Transformers.Add.validate(parameters)
  end

  defp validate_transform("subtract", parameters) do
    Transformers.Subtract.validate(parameters)
  end

  defp validate_transform("multiplication", parameters) do
    Transformers.Multiplication.validate(parameters)
  end

  defp validate_transform("division", parameters) do
    Transformers.Division.validate(parameters)
  end

  defp validate_transform("constant", parameters) do
    Transformers.Constant.validate(parameters)
  end

  defp validate_transform(unsupported, _) do
    {:error, "Unsupported transformation validation type: #{unsupported}"}
  end
end
