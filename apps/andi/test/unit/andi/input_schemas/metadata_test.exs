defmodule Andi.InputSchemas.MetadataTest do
  use ExUnit.Case

  alias Ecto.Changeset
  alias Andi.InputSchemas.Metadata
  alias SmartCity.TestDataGenerator

  test "SmartCity.Dataset => Changeset => SmartCity.Dataset works" do
    dataset =
      TestDataGenerator.create_dataset(%{
        business: %{issuedDate: "2020-01-03 00:00:00Z", modifiedDate: "2020-01-05 00:00:00Z"}
      })

    new_dataset =
      dataset
      |> Metadata.changeset_from_struct()
      |> Changeset.apply_changes()
      |> Metadata.restruct(dataset)

    assert new_dataset == dataset
  end
end
