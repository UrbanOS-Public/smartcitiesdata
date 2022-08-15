defmodule Transformers.Validations.ValidationStatus do

  defstruct values: %{}, errors: %{}

  def update_value(status, field, value) do
    Map.update(status, :values, %{}, fn values -> Map.put(values, field, value) end)
  end

  def add_error(status, field, error) do
    Map.update(status, :errors, %{}, fn errors -> Map.put_new(errors, field, error) end)
  end

  def get_value(status, field) do
    Map.get(status, :values) |> Map.get(field)
  end

  def get_error(status, field) do
    Map.get(status, :errors) |> Map.get(field)
  end

  def has_error?(status, field) do
    Map.get(status, :errors) |> Map.has_key?(field)
  end

  def any_errors?(status) do
    Map.get(status, :errors) |> Map.keys() |> length() |> greater_than_zero?()
  end

  defp greater_than_zero?(length) do
    length > 0
  end

  def ordered_values_or_errors(status, field_order) do
    if any_errors?(status) do
      {:error, status.errors}
    else
      ordered = Enum.map(field_order, fn field -> get_value(status, field) end)
      {:ok, ordered}
    end
  end
end
