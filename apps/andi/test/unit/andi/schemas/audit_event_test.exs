defmodule Andi.Schemas.AuditEventTest do
  use ExUnit.Case
  import Checkov

  alias Andi.Schemas.AuditEvent
  import SmartCity.Event
  alias SmartCity.TestDataGenerator, as: TDG

  @valid_changes %{
    user_id: "test_user",
    event_type: dataset_update(),
    event: TDG.create_dataset(%{})
  }

  describe "changeset" do
    test "returns a valid changeset from a map and adds a UUID if one is not passed" do
      changeset = AuditEvent.changeset(@valid_changes)
      assert changeset.valid?
      refute changeset.changes.id == nil
      assert changeset.changes.user_id == "test_user"
      assert changeset.changes.event_type == dataset_update()
      assert changeset.changes.event == @valid_changes.event
    end

    data_test "requires value for #{inspect(field_path)}" do
      changes = delete_in(@valid_changes, field_path)

      changeset = AuditEvent.changeset(changes)

      refute changeset.valid?

      [field] = field_path

      errors = accumulate_errors(changeset)
      assert get_in(errors, field_path) == [{field, {"is required", [validation: :required]}}]

      where(
        field_path: [
          [:user_id],
          [:event_type],
          [:event]
        ]
      )
    end

    test "requires that the id be a UUID, if passed" do
      changes = %{
        user_id: "test_user",
        event_type: dataset_update(),
        event: TDG.create_dataset(%{}),
        id: "not-a-uuid"
      }

      changeset = AuditEvent.changeset(changes)

      refute changeset.valid?

      errors = accumulate_errors(changeset)
      assert [id: {"is invalid", [type: Ecto.UUID, validation: :cast]}] == errors.id
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
