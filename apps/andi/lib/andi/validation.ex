defmodule DatasetValidator do
  @moduledoc false

  def validate(dataset) do
    SimplyValidate.validate(dataset, [
      modified_date_iso8601(),
      description_required()
    ])
  end

  defp description_required do
    {&(&1.description != ""), "Description must be provided"}
  end

  defp modified_date_iso8601 do
    {&is_valid_modified_date?(&1.modified_date), "Modified date must be in a valid IOS8601 timestamp format"}
  end

  defp is_valid_modified_date?(""), do: true

  defp is_valid_modified_date?(modified_date) when modified_date != "" do
    case DateTime.from_iso8601(modified_date) do
      {:ok, _, _} -> true
      {:error, _} -> false
    end
  end
end
