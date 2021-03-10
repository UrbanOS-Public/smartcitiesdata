defmodule Andi.Event.EventHandlerTest do
  use ExUnit.Case
  use Andi.DataCase

  import SmartCity.TestHelper
  import SmartCity.Event, only: [user_login: 0]
  alias Andi.Schemas.User

  @instance_name Andi.instance_name()

  describe "#{user_login()}" do
    test "persists user if subject id does not match one in ecto" do
      new_user_subject_id = UUID.uuid4()
      user = User.changeset(%User{}, %{subject_id: new_user_subject_id, email: "cam@cam.com"}) |> Ecto.Changeset.apply_changes()
      assert nil == User.get_by_subject_id(user.subject_id)

      Brook.Event.send(@instance_name, user_login(), __MODULE__, user)

      eventually(
        fn ->
          user_from_ecto = User.get_by_subject_id(new_user_subject_id)
          assert user_from_ecto != nil
          assert user_from_ecto.subject_id == user.subject_id
          assert user_from_ecto.email == user.email
        end,
        1_000,
        30
      )
    end

    test "does not persist user if subject_id already exists" do
      old_user_subject_id = UUID.uuid4()
      {:ok, user} = User.create_or_update(old_user_subject_id, %{subject_id: old_user_subject_id, email: "blah@blah.com"})
      assert %{subject_id: _} = User.get_by_subject_id(old_user_subject_id)

      new_user_same_subject_id = Map.put(user, :email, "cam@cam.com")
      Brook.Event.send(@instance_name, user_login(), __MODULE__, new_user_same_subject_id)

      user_from_ecto = User.get_by_subject_id(old_user_subject_id)
      assert user_from_ecto.id == user.id
    end
  end
end
