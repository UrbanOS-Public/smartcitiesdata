defmodule Dictionary do
  @moduledoc """
  Provides the functionality for retrieving dictionary
  data types to determine the correct Type module to
  cast payload fields to, as well as the `normalize/2`
  function for invoking a field's implementation of the
  Normalizer protocol to normalize the supplied message
  data against the expected type based on its schema.
  """

  @type t :: Dictionary.Impl.t()

  defmodule InvalidFieldError do
    defexception [:message, :field]
  end

  defmodule InvalidTypeError do
    defexception [:message]
  end

  defdelegate from_list(list), to: Dictionary.Impl
  defdelegate get_field(dictionary, name), to: Dictionary.Impl
  defdelegate get_by_type(dictionary, type), to: Dictionary.Impl
  defdelegate update_field(dictionary, name, field_or_function), to: Dictionary.Impl
  defdelegate delete_field(dictionary, name), to: Dictionary.Impl
  defdelegate validate_field(dictionary, path, type), to: Dictionary.Impl

  @spec normalize(dictionary :: Dictionary.t(), payload :: map) ::
          {:ok, map} | {:error, %{String.t() => term}}
  def normalize(dictionary, payload) when is_map(payload) do
    dictionary
    |> Enum.reduce(%{data: %{}, errors: %{}}, &normalize_field(payload, &1, &2))
    |> handle_normalization_context()
  end

  defp normalize_field(payload, %{name: name} = field, context) do
    value = Map.get(payload, name)

    case Dictionary.Type.Normalizer.normalize(field, value) do
      {:ok, new_value} -> update_in(context, [:data], &Map.put(&1, name, new_value))
      {:error, error} -> update_in(context, [:errors], &Map.put(&1, name, error))
    end
  end

  defp handle_normalization_context(%{errors: errors}) when errors != %{} do
    Ok.error(errors)
  end

  defp handle_normalization_context(%{data: data}), do: Ok.ok(data)
end
