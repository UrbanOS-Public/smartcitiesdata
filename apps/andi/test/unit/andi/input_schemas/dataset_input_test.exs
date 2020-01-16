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
    schema: [%{name: "name", type: "type"}],
    sourceFormat: "sourceFormat",
    sourceType: "sourceType"
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
          :sourceFormat,
          :sourceType
        ]
      )
    end

    test "treats empty string values as changes" do
      changes =
        @valid_changes
        |> Map.put(:spatial, "")
        |> Map.put(:temporal, "")

      changeset = DatasetInput.changeset(changes)

      assert changeset.errors == []
      assert changeset.changes[:spatial] == ""
      assert changeset.changes[:temporal] == ""
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

      where(
        field_name: [
          :orgName,
          :dataName
        ]
      )
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

      assert changeset.errors == [
               {:topLevelSelector, {"is required", [validation: :required]}}
             ]

      where(source_format: ["xml", "text/xml"])
    end

    data_test "validates the schema appropriately when sourceType is #{source_type} and schema is #{inspect(schema)}" do
      changes = @valid_changes |> Map.put(:schema, schema) |> Map.put(:sourceType, source_type)

      changeset = DatasetInput.changeset(changes)

      assert changeset.errors == errors

      where(
        source_type: ["ingest", "stream", "ingest", "something-else"],
        schema: [nil, nil, [], nil],
        errors: [
          [{:schema, {"is required", [validation: :required]}}],
          [{:schema, {"is required", [validation: :required]}}],
          [{:schema, {"cannot be empty", []}}],
          []
        ]
      )
    end

    test "xml source format requires all fields in the schema to have selectors" do
      schema = [
        %{name: "field_name"},
        %{name: "other_field", selector: "this is the only selector"},
        %{name: "another_field", selector: ""}
      ]

      changes =
        @valid_changes
        |> Map.merge(%{
          schema: schema,
          sourceFormat: "xml",
          topLevelSelector: "whatever",
          sourceType: "ingest"
        })

      changeset = DatasetInput.changeset(changes)

      assert length(changeset.errors) == 2

      assert changeset.errors
             |> Enum.any?(fn {:schema, {error, _}} -> String.match?(error, ~r/selector.+field_name/) end)

      assert changeset.errors
             |> Enum.any?(fn {:schema, {error, _}} -> String.match?(error, ~r/selector.+another_field/) end)
    end
  end
end
