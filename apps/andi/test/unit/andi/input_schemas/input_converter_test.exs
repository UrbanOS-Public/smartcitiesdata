defmodule Andi.InputSchemas.InputConverterTest do
  use ExUnit.Case

  alias Ecto.Changeset
  alias Andi.InputSchemas.InputConverter
  alias SmartCity.TestDataGenerator

  test "SmartCity.Dataset => Changeset => SmartCity.Dataset" do
    dataset =
      TestDataGenerator.create_dataset(%{
        business: %{issuedDate: "2020-01-03 00:00:00Z", modifiedDate: "2020-01-05 00:00:00Z"}
      })

    new_dataset =
      dataset
      |> InputConverter.changeset_from_struct()
      |> Changeset.apply_changes()
      |> InputConverter.restruct(dataset)

    assert new_dataset == dataset
  end

  test "conversion preserves empty string modified date" do
    dataset =
      TestDataGenerator.create_dataset(%{
        business: %{issuedDate: "2020-01-03 00:00:00Z", modifiedDate: ""}
      })

    new_dataset =
      dataset
      |> InputConverter.changeset_from_struct()
      |> Changeset.apply_changes()
      |> InputConverter.restruct(dataset)

    assert new_dataset == dataset
  end
end
