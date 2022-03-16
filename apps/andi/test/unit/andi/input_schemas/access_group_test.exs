defmodule Andi.Schemas.AccessGroupTest do
  use ExUnit.Case
  import Checkov
  use Placebo

  alias Andi.InputSchemas.AccessGroup

  @valid_changes %{
    name: "Access Group Name"
  }

  describe "changeset" do
    test "returns a valid changeset from a map and adds a UUID if one is not passed" do
      changeset = AccessGroup.changeset(@valid_changes)
      assert changeset.valid?
      refute changeset.changes.id == nil
      assert changeset.changes.name == "Access Group Name"
    end

    test "returns a valid changeset from a Smart City Access Group and adds a UUID if one is not passed" do
      uuid = UUID.uuid4()
      {:ok, access_group} = SmartCity.AccessGroup.new(%{name: "Smrt Access Group", id: uuid})
      changeset = AccessGroup.changeset(access_group)
      assert changeset.valid?
      refute changeset.changes.id == nil
      assert changeset.changes.name == "Smrt Access Group"
    end

    data_test "requires value for #{inspect(field_path)}" do
      changes = delete_in(@valid_changes, field_path)

      changeset = AccessGroup.changeset(changes)

      refute changeset.valid?

      [field] = field_path

      errors = accumulate_errors(changeset)
      assert get_in(errors, field_path) == [{field, {"is required", [validation: :required]}}]

      where(
        field_path: [
          [:name]
        ]
      )
    end

    test "requires that the id be a UUID, if passed" do
      changes = %{
        name: "Test Access Group",
        id: "not-a-uuid"
      }

      changeset = AccessGroup.changeset(changes)

      refute changeset.valid?

      errors = accumulate_errors(changeset)
      assert errors.id == [id: {"must be a valid UUID", []}, id: {"is invalid", [type: Ecto.UUID, validation: :cast]}]

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
