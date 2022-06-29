defmodule Andi.InputSchemas.Datasets.DatasetTest do
  use ExUnit.Case
  import Checkov
  use Placebo

  alias Andi.InputSchemas.Datasets.Dataset
  alias Andi.InputSchemas.Datasets

  @source_query_param_id Ecto.UUID.generate()
  @source_header_id Ecto.UUID.generate()

  @valid_changes %{
    id: "id",
    business: %{
      benefitRating: 0,
      riskRating: 1,
      contactEmail: "contact@email.com",
      contactName: "contactName",
      dataTitle: "dataTitle",
      orgTitle: "orgTitle",
      description: "description",
      issuedDate: "2020-01-01T00:00:00Z",
      license: "https://www.test.net",
      publishFrequency: "publishFrequency"
    },
    technical: %{
      dataName: "dataName",
      orgName: "orgName",
      private: false,
      sourceHeaders: [
        %{id: Ecto.UUID.generate(), key: "foo", value: "bar"},
        %{id: @source_header_id, key: "fizzle", value: "bizzle"}
      ],
      sourceQueryParams: [
        %{id: Ecto.UUID.generate(), key: "chain", value: "city"},
        %{id: @source_query_param_id, key: "F# minor", value: "add"}
      ],
      sourceType: "sourceType",
      sourceUrl: "https://sourceurl.com?chain=city&F%23+minor=add"
    }
  }

  describe "changeset" do
    data_test "requires value for #{inspect(field_path)}" do
      changes = delete_in(@valid_changes, field_path)

      changeset = Dataset.changeset(changes)

      refute changeset.valid?

      [_, field] = field_path

      errors = accumulate_errors(changeset)
      assert get_in(errors, field_path) == [{field, {"is required", [validation: :required]}}]

      where(
        field_path: [
          [:business, :benefitRating],
          [:business, :contactEmail],
          [:business, :contactName],
          [:business, :dataTitle],
          [:business, :orgTitle],
          [:business, :description],
          [:business, :issuedDate],
          [:business, :publishFrequency],
          [:business, :riskRating],
          [:business, :license],
          [:technical, :dataName],
          [:technical, :orgName],
          [:technical, :private],
          [:technical, :sourceType]
        ]
      )
    end

    test "treats empty string values as changes" do
      changes =
        @valid_changes
        |> put_in([:business, :spatial], "")
        |> put_in([:business, :temporal], "")

      changeset = Dataset.changeset(changes)

      assert changeset.valid?
      assert accumulate_errors(changeset) == %{}

      business = changeset.changes.business
      assert business.changes.spatial == ""
      assert business.changes.temporal == ""
    end

    test "requires valid email" do
      changes = @valid_changes |> put_in([:business, :contactEmail], "nope")

      changeset = Dataset.changeset(changes)

      refute changeset.valid?

      assert accumulate_errors(changeset) == %{
               business: %{
                 contactEmail: [{:contactEmail, {"has invalid format", [validation: :format]}}]
               }
             }
    end

    data_test "requires #{inspect(field_path)} be a date" do
      changes = @valid_changes |> put_in(field_path, "2020-13-32")

      changeset = Dataset.changeset(changes)

      refute changeset.valid?

      [_, field_name] = field_path
      errors = accumulate_errors(changeset)
      assert [{^field_name, _}] = get_in(errors, field_path)

      where(
        field_path: [
          [:business, :issuedDate],
          [:business, :modifiedDate]
        ]
      )
    end

    data_test "rejects dashes in the #{inspect(field_path)}" do
      changes = @valid_changes |> put_in(field_path, "this-has-dashes")

      changeset = Dataset.changeset(changes)

      refute changeset.valid?

      [_, field_name] = field_path
      errors = accumulate_errors(changeset)
      assert get_in(errors, field_path) == [{field_name, {"cannot contain dashes", [validation: :format]}}]

      where(
        field_path: [
          [:technical, :orgName],
          [:technical, :dataName]
        ]
      )
    end

    data_test "is invalid when #{inspect(field_path)} has an unacceptable value" do
      changes = @valid_changes |> put_in(field_path, value)
      changeset = Dataset.changeset(changes)

      refute changeset.valid?

      [_, field] = field_path
      errors = accumulate_errors(changeset)
      assert [{^field, {^message, _}}] = get_in(errors, field_path)

      where([
        [:field_path, :value, :message],
        [[:business, :benefitRating], 0.7, "should be one of [0.0, 0.5, 1.0]"],
        [[:business, :benefitRating], 1.1, "should be one of [0.0, 0.5, 1.0]"],
        [[:business, :riskRating], 3.14159, "should be one of [0.0, 0.5, 1.0]"],
        [[:business, :riskRating], 0.000001, "should be one of [0.0, 0.5, 1.0]"]
      ])
    end

    data_test "#{inspect(field_path)} are invalid when any key is not set" do
      changes =
        @valid_changes
        |> put_in(field_path, [
          %{id: Ecto.UUID.generate(), key: "foo", value: "bar"},
          %{id: Ecto.UUID.generate(), key: "", value: "where's my key?"}
        ])

      changeset = Dataset.changeset(changes)

      refute changeset.valid?

      [_, field] = field_path

      assert {field, {"has invalid format", [validation: :format]}} in changeset.changes.technical.errors

      where(field_path: [[:technical, :sourceQueryParams], [:technical, :sourceHeaders]])
    end

    data_test "#{inspect(field_path)} are valid when they are not set" do
      changes = @valid_changes |> delete_in(field_path)

      changeset = Dataset.changeset(changes)

      assert %{} == accumulate_errors(changeset)
      assert changeset.valid?

      where(field_path: [[:technical, :sourceQueryParams], [:technical, :sourceHeaders]])
    end
  end

  describe "title conversion" do
    data_test "In case of #{condition}, title #{title} is converted to name #{expected_name}" do
      assert Datasets.data_title_to_data_name(title, 20) == expected_name

      where([
        [:condition, :title, :expected_name],
        ["special characters", "Bob-Data, The Finest!", "bobdata_the_finest"],
        ["double spaces", "This  is the   data", "this_is_the_data"],
        ["over max length", "Bob-Data, The Finest! The Best!", "bobdata_the_finest"]
      ])
    end
  end

  defp accumulate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn _changeset, field, {msg, opts} ->
      {field, {msg, opts}}
    end)
  end

  defp delete_in(data, path) do
    pop_in(data, path) |> elem(1)
  end
end
