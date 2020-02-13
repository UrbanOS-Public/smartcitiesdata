defmodule Andi.InputSchemas.DatasetInputTest do
  use ExUnit.Case
  import Checkov
  use Placebo
  alias SmartCity.TestDataGenerator, as: TDG

  alias Andi.InputSchemas.DatasetInput
  alias Andi.DatasetCache

  @source_query_param_id Ecto.UUID.generate()

  @valid_changes %{
    benefitRating: 0,
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
    riskRating: 1,
    schema: [%{name: "name", type: "type"}],
    sourceFormat: "sourceFormat",
    sourceQueryParams: [
      %{id: Ecto.UUID.generate(), key: "foo", value: "bar"},
      %{id: @source_query_param_id, key: "fizzle", value: "bizzle"}
    ],
    sourceType: "sourceType",
    sourceUrl: "sourceurl.com"
  }

  setup do
    GenServer.call(DatasetCache, :reset)
  end

  describe "light_validation_changeset" do
    data_test "requires value for #{field_name}" do
      changes = @valid_changes |> Map.delete(field_name)

      changeset = DatasetInput.light_validation_changeset(changes)

      assert changeset.errors == [{field_name, {"is required", [validation: :required]}}]

      where(
        field_name: [
          :benefitRating,
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
          :riskRating,
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

      changeset = DatasetInput.light_validation_changeset(changes)

      assert changeset.errors == []
      assert changeset.changes[:spatial] == ""
      assert changeset.changes[:temporal] == ""
    end

    test "requires valid email" do
      changes = @valid_changes |> Map.put(:contactEmail, "nope")

      changeset = DatasetInput.light_validation_changeset(changes)

      assert changeset.errors == [{:contactEmail, {"has invalid format", [validation: :format]}}]
    end

    data_test "requires #{field_name} be a date" do
      changes = @valid_changes |> Map.put(field_name, "2020-13-32")

      changeset = DatasetInput.light_validation_changeset(changes)

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

      changeset = DatasetInput.light_validation_changeset(changes)

      assert changeset.errors == [{field_name, {"cannot contain dashes", [validation: :format]}}]

      where(
        field_name: [
          :orgName,
          :dataName
        ]
      )
    end

    data_test "topLevelSelector is required when sourceFormat is #{source_format}" do
      changes = @valid_changes |> Map.put(:sourceFormat, source_format)

      changeset = DatasetInput.light_validation_changeset(changes)

      assert changeset.errors == [
               {:topLevelSelector, {"is required", [validation: :required]}}
             ]

      where(source_format: ["xml", "text/xml"])
    end

    data_test "validates the schema appropriately when sourceType is #{source_type} and schema is #{inspect(schema)}" do
      changes = @valid_changes |> Map.put(:schema, schema) |> Map.put(:sourceType, source_type)

      changeset = DatasetInput.light_validation_changeset(changes)

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

      changeset = DatasetInput.light_validation_changeset(changes)

      assert length(changeset.errors) == 2

      assert changeset.errors
             |> Enum.any?(fn {:schema, {error, _}} -> String.match?(error, ~r/selector.+field_name/) end)

      assert changeset.errors
             |> Enum.any?(fn {:schema, {error, _}} -> String.match?(error, ~r/selector.+another_field/) end)
    end

    data_test "is invalid when #{field} has an unacceptable value" do
      changes = @valid_changes |> Map.put(field, value)
      changeset = DatasetInput.light_validation_changeset(changes)

      assert [{^field, {^message, _}}] = changeset.errors

      where([
        [:field, :value, :message],
        [:benefitRating, 0.7, "should be one of [0.0, 0.5, 1.0]"],
        [:benefitRating, 1.1, "should be one of [0.0, 0.5, 1.0]"],
        [:riskRating, 3.14159, "should be one of [0.0, 0.5, 1.0]"],
        [:riskRating, 0.000001, "should be one of [0.0, 0.5, 1.0]"]
      ])
    end

    test "sourceQueryParams are invalid when any key is not set" do
      changes = @valid_changes |> Map.put(:sourceQueryParams, [
        %{id: Ecto.UUID.generate(), key: "foo", value: "bar"},
        %{id: Ecto.UUID.generate(), key: "", value: "where's my key?"}
      ])

      changeset = DatasetInput.light_validation_changeset(changes)

      assert changeset.errors == [{:sourceQueryParams, {"has invalid format", [validation: :format]}}]
    end

    test "sourceQueryParams are valid when they are not set" do
      changes = @valid_changes |> Map.delete(:sourceQueryParams)

      changeset = DatasetInput.light_validation_changeset(changes)

      assert changeset.valid?
      assert Enum.empty?(changeset.errors)
    end
  end

  describe "full_validation_changeset" do
    test "requires unique orgName and dataName" do
      changes = @valid_changes |> Map.delete(:id)

      existing_dataset =
        TDG.create_dataset(%{technical: %{dataName: @valid_changes.dataName, orgName: @valid_changes.orgName}})

      DatasetCache.put(existing_dataset)

      changeset = DatasetInput.full_validation_changeset(changes)

      assert changeset.errors == [{:dataName, {"existing dataset has the same orgName and dataName", []}}]
    end

    test "allows same orgName and dataName when id is same" do
      existing_dataset =
        TDG.create_dataset(%{
          id: @valid_changes.id,
          technical: %{dataName: @valid_changes.dataName, orgName: @valid_changes.orgName}
        })

      DatasetCache.put(existing_dataset)

      changeset = DatasetInput.full_validation_changeset(@valid_changes)

      assert changeset.errors == []
    end

    test "includes light validation" do
      changes = @valid_changes |> Map.put(:contactEmail, "nope") |> Map.delete(:sourceFormat)

      changeset = DatasetInput.full_validation_changeset(changes)

      assert {:contactEmail, {"has invalid format", [validation: :format]}} in changeset.errors
      assert {:sourceFormat, {"is required", [validation: :required]}} in changeset.errors
    end
  end

  describe "add_source_query_param" do
    setup do
      %{changeset: DatasetInput.light_validation_changeset(@valid_changes)}
    end

    test "appends key/value to the sourceQueryParams", %{changeset: changeset} do
      new_param = %{key: "key2", value: "value2"}

      changes =
        DatasetInput.add_source_query_param(changeset, new_param)
        |> Ecto.Changeset.apply_changes()

      assert length(changes.sourceQueryParams) == length(@valid_changes.sourceQueryParams) + 1
      refute is_nil(List.last(changes.sourceQueryParams).id)
      assert List.last(changes.sourceQueryParams).key == new_param.key
      assert List.last(changes.sourceQueryParams).value == new_param.value
    end

    test "appends an empty key/value to the sourceQueryParams by default", %{changeset: changeset} do
      changes =
        DatasetInput.add_source_query_param(changeset)
        |> Ecto.Changeset.apply_changes()

      assert length(changes.sourceQueryParams) == length(@valid_changes.sourceQueryParams) + 1
      refute is_nil(List.last(changes.sourceQueryParams).id)
      assert is_nil(List.last(changes.sourceQueryParams).key)
      assert is_nil(List.last(changes.sourceQueryParams).value)
    end

    test "appends a key/value to an empty list of sourceQueryParams" do
      new_param = %{key: "key2", value: "value2"}

      changeset =
        @valid_changes
        |> Map.put(:sourceQueryParams, %{})
        |> DatasetInput.light_validation_changeset()

      changes =
        DatasetInput.add_source_query_param(changeset, new_param)
        |> Ecto.Changeset.apply_changes()

      assert length(changes.sourceQueryParams) == 1
      refute is_nil(hd(changes.sourceQueryParams).id)
      assert hd(changes.sourceQueryParams).key == new_param.key
      assert hd(changes.sourceQueryParams).value == new_param.value
    end
  end

  describe "remove_source_query_param" do
    setup do
      %{changeset: DatasetInput.light_validation_changeset(@valid_changes)}
    end

    test "removes key/value from the sourceQueryParams by id", %{changeset: changeset} do
      changes =
        DatasetInput.remove_source_query_param(changeset, @source_query_param_id)
        |> Ecto.Changeset.apply_changes()

      assert length(changes.sourceQueryParams) == length(@valid_changes.sourceQueryParams) - 1
      refute Enum.any?(changes.sourceQueryParams, fn param -> param.id == @source_query_param_id end)
    end

    test "does nothing if id is unknown", %{changeset: changeset} do
      assert changeset == DatasetInput.remove_source_query_param(changeset, "unknown")
    end
  end
end
