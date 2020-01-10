defmodule Andi.InputSchemas.DatasetInputTest do
  use ExUnit.Case
  import Checkov
  use Placebo
  alias SmartCity.TestDataGenerator, as: TDG

  alias Andi.InputSchemas.DatasetInput
  alias Andi.Services.DatasetRetrieval

  @valid_changes %{
    contactEmail: "contact@email.com",
    contactName: "contactName",
    dataName: "dataName",
    dataTitle: "dataTitle",
    description: "description",
    id: "id",
    issuedDate: "2020-01-01T00:00:00Z",
    license: "license",
    orgName: "orgName",
    orgTitle: "orgTitle",
    private: false,
    publishFrequency: "publishFrequency",
    sourceFormat: "sourceFormat"
  }

  describe "changeset" do
    setup do
      allow DatasetRetrieval.get_all!(), return: []
      :ok
    end

    data_test "requires value for #{field_name}" do
      changes = @valid_changes |> Map.delete(field_name)

      changeset = DatasetInput.changeset(changes)

      assert changeset.errors == [{field_name, {"is required", [validation: :required]}}]

      where(
        field_name: [
          :contactEmail,
          :contactName,
          :dataName,
          :dataTitle,
          :description,
          :issuedDate,
          :license,
          :orgName,
          :orgTitle,
          :private,
          :publishFrequency,
          :sourceFormat
        ]
      )
    end

    test "requires valid email" do
      changes = @valid_changes |> Map.put(:contactEmail, "nope")

      changeset = DatasetInput.changeset(changes)

      assert changeset.errors == [{:contactEmail, {"has invalid format", [validation: :format]}}]
    end

    data_test "requires #{field_name} be a date" do
      changes = @valid_changes |> Map.put(field_name, "2020-13-32")

      changeset = DatasetInput.changeset(changes)

      assert [{^field_name, _}] = changeset.errors

      where(
        field_name: [
          :issuedDate,
          :modifiedDate
        ]
      )
    end

    data_test "rejects dashes in the #{field_name}" do
      changes = @valid_changes |> Map.put(field_name, "this-has-dashes")

      changeset = DatasetInput.changeset(changes)

      assert changeset.errors == [{field_name, {"cannot contain dashes", [validation: :format]}}]

      where(field_name: [:orgName, :dataName])
    end

    test "requires unique orgName and dataName" do
      Placebo.unstub()

      changes = @valid_changes |> Map.delete(:id)

      existing_dataset =
        TDG.create_dataset(%{technical: %{dataName: @valid_changes.dataName, orgName: @valid_changes.orgName}})

      allow DatasetRetrieval.get_all!(), return: [existing_dataset]

      changeset = DatasetInput.changeset(changes)

      assert changeset.errors == [{:dataName, {"existing dataset has the same orgName and dataName", []}}]
    end

    test "allows same orgName and dataName when id is same" do
      Placebo.unstub()

      existing_dataset =
        TDG.create_dataset(%{
          id: @valid_changes.id,
          technical: %{dataName: @valid_changes.dataName, orgName: @valid_changes.orgName}
        })

      allow DatasetRetrieval.get_all!(), return: [existing_dataset]

      changeset = DatasetInput.changeset(@valid_changes)

      assert changeset.errors == []
    end

    data_test "topLevelSelector is required when sourceFormat is #{source_format}" do
      changes = @valid_changes |> Map.put(:sourceFormat, source_format)

      changeset = DatasetInput.changeset(changes)

      assert changeset.errors == [{:topLevelSelector, {"is required", [validation: :required]}}]

      where(source_format: ["xml", "text/xml"])
    end
  end
end
