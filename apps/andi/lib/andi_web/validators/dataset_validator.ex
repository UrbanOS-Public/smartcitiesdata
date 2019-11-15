defmodule AndiWeb.DatasetValidator do
  @moduledoc "Used to validate datasets"

  alias Andi.Services.DatasetRetrieval
  alias AndiWeb.DatasetSchemaValidator

  # TODO: first convert entire dataset to string keys so we don't have to match on atom AND string keys
  def validate(dataset) do
    stringified = stringify_keys(dataset)
    result =
      SimplyValidate.validate(stringified, [
        validate_org_name(),
        validate_data_name(),
        validate_modified_date_format(),
        already_exists!(),
        description_required(),
        validate_top_level_selector_if_required()
      ]) ++
      DatasetSchemaValidator.validate(stringified)

    case result do
      [] -> :valid
      errors -> {:invalid, errors}
    end
  end

  def validate_org_name do
    {&String.contains?(&1["technical"]["orgName"], "-"), "orgName cannot contain dashes", false}
  end

  def validate_data_name do
    {&String.contains?(&1["technical"]["dataName"], "-"), "dataName cannot contain dashes", false}
  end

  def validate_modified_date_format do
    {&check_valid_date(&1["business"]["modifiedDate"]),
     "modifiedDate must be iso8601 formatted, e.g. '2019-01-01T13:59:45'", true}
  end

  def already_exists! do
    {&check_already_exists/1, "Existing dataset has the same orgName and dataName", false}
  end

  defp check_already_exists(dataset) do
    existing_datasets = DatasetRetrieval.get_all!()

    Enum.any?(existing_datasets, fn existing_dataset ->
      stringified_existing_dataset = stringify_keys(existing_dataset)

      different_ids(dataset, stringified_existing_dataset) &&
        same_system_name(dataset, stringified_existing_dataset)
    end)
  end

  def validate_top_level_selector_if_required() do
    {&has_top_level_selector_if_required/1, "topLevelSelector required for xml datasets", true}
  end

  defp has_top_level_selector_if_required(%{
         "technical" => %{"topLevelSelector" => topLevelSelector, "sourceFormat" => "text/xml"}
       }) do
    topLevelSelector != nil
  end

  defp has_top_level_selector_if_required(_), do: true

  defp same_system_name(%{"technical" => %{"systemName" => left}}, %{"technical" => %{"systemName" => right}}), do: left == right

  defp different_ids(%{"id" => left}, %{"id" => right}), do: left != right

  defp description_required do
    {&(&1["business"]["description"] != ""), "Description must be provided"}
  end

  defp check_valid_date(""), do: true

  defp check_valid_date(date) do
    case DateTime.from_iso8601(date) do
      {:ok, _date, _offset} ->
        true

      _ ->
        false
    end
  end

  # Handles preconverting datasets from structs to maps for comparison purposes
  defp stringify_keys(%{__struct__: _} = struct), do: struct |> Map.from_struct() |> stringify_keys()

  defp stringify_keys(map = %{}) do
    map
    |> Enum.map(fn {key, value} -> {key_to_string(key), stringify_keys(value)} end)
    |> Enum.into(%{})
  end

  defp stringify_keys([head | rest]) do
    [stringify_keys(head) | stringify_keys(rest)]
  end

  defp stringify_keys(not_a_map) do
    not_a_map
  end

  defp key_to_string(key) when is_atom(key), do: Atom.to_string(key)

  defp key_to_string(key), do: key
end
