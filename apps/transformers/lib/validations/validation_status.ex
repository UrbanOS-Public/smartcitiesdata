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

  def any_errors?(status) do
    Map.get(status, :errors) |> Map.keys() |> length() |> greater_than_zero?()
  end

  defp greater_than_zero?(length) do
    length > 0
  end
end
