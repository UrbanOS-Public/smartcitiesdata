defmodule AndiWeb.DatasetValidator do
  @moduledoc "Used to validate datasets"

  import Andi, only: [instance_name: 0]

  def validate(dataset) do
    case SimplyValidate.validate(dataset, [
           validate_system_name(),
           already_exists!(),
           modified_date_iso8601(),
           description_required()
         ]) do
      [] -> :valid
      errors -> {:invalid, errors}
    end
  end

  def validate_system_name do
    {&String.contains?(&1.technical.systemName, "-"), "systemName cannot contain dashes", false}
  end

  def already_exists! do
    {&check_already_exists/1, "Existing dataset has the same orgName and dataName", false}
  end

  #########################
  ##  Private Functions  ##
  #########################
  defp check_already_exists(dataset) do
    existing_datasets = Brook.get_all_values!(instance_name(), :dataset)

    Enum.any?(existing_datasets, fn existing_dataset ->
      different_ids(dataset, existing_dataset) &&
        same_system_name(dataset, existing_dataset)
    end)
  end

  defp same_system_name(a, b), do: a.technical.systemName == b.technical.systemName
  defp different_ids(a, b), do: a.id != b.id

  defp description_required do
    {&(&1.business.description != ""), "Description must be provided"}
  end

  defp modified_date_iso8601 do
    {&is_valid_modified_date?(&1.business.modifiedDate), "modifiedDate must be in a valid IOS8601 timestamp format"}
  end

  defp is_valid_modified_date?(""), do: true

  defp is_valid_modified_date?(modified_date) do
    case DateTime.from_iso8601(modified_date) do
      {:ok, _, _} -> true
      {:error, _} -> false
    end
  end
end
