defmodule EditorHelpers do
  @moduledoc """
    Helper functions for editor field tests
  """

  alias Andi.InputSchemas.InputConverter

  def dataset_to_form_data(dataset) do
    dataset
    |> InputConverter.changeset_from_dataset()
    |> form_data_for_save()
  end

  defp form_data_for_save(changeset) do
    changeset
    |> Ecto.Changeset.apply_changes()
    |> Map.update!(:keywords, &Enum.join(&1, ", "))
    # until we add the ability to edit the schema/dictionary, putting a fake one on there for validation
    |> Map.put(:schema, dummy_schema())
  end

  defp dummy_schema() do
    %{"0" => %{"name" => "ignored_name", "type" => "ignored_type"}}
  end
end
