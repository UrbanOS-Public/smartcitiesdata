defmodule Andi.Schemas.UserTest do
  use ExUnit.Case
  
  import Checkov

  alias Andi.Schemas.User

  @subject_id Ecto.UUID.generate()

  @valid_changes %{
    subject_id: @subject_id,
    email: "test@test.com"
  }

  describe "changeset" do
    data_test "requires value for #{inspect(field_path)}" do
      changes = delete_in(@valid_changes, field_path)

      changeset = User.changeset(changes)

      refute changeset.valid?

      [field] = field_path

      errors = accumulate_errors(changeset)
      assert get_in(errors, field_path) == [{field, {"can't be blank", [validation: :required]}}]

      where(
        field_path: [
          [:subject_id],
          [:email]
        ]
      )
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
