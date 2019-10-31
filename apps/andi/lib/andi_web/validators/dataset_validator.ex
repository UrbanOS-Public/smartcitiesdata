defmodule AndiWeb.DatasetValidator do
  @moduledoc "Used to validate datasets"

  alias Andi.Services.DatasetRetrieval

  def validate(dataset) do
    case SimplyValidate.validate(dataset, [
           validate_org_name(),
           validate_data_name(),
           validate_modified_date_format(),
           already_exists!(),
           description_required()
         ]) do
      [] -> :valid
      errors -> {:invalid, errors}
    end
  end

  def validate_org_name do
    {&String.contains?(&1.technical.orgName, "-"), "orgName cannot contain dashes", false}
  end

  def validate_data_name do
    {&String.contains?(&1.technical.dataName, "-"), "dataName cannot contain dashes", false}
  end

  def validate_modified_date_format do
    {&check_valid_date(&1.business.modifiedDate), "modifiedDate must be iso8601 formatted, e.g. '2019-01-01T13:59:45'",
     true}
  end

  def already_exists! do
    {&check_already_exists/1, "Existing dataset has the same orgName and dataName", false}
  end

  #########################
  ##  Private Functions  ##
  #########################
  defp check_already_exists(dataset) do
    existing_datasets = DatasetRetrieval.get_all!()

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

  defp check_valid_date(""), do: true

  defp check_valid_date(date) do
    case DateTime.from_iso8601(date) do
      {:ok, _date, _offset} ->
        true

      _ ->
        false
    end
  end
end
