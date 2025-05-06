defmodule AndiWeb.UserLiveViewTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase

  @moduletag shared_data_connection: true

  import Phoenix.LiveViewTest
  import SmartCity.TestHelper, only: [eventually: 1]

  import FlokiHelpers,
    only: [
      get_texts: 2
    ]

  alias SmartCity.TestDataGenerator, as: TDG

  alias Andi.Schemas.User

  @instance_name Andi.instance_name()

  @url_path "/users"

  describe "public user access" do
    setup do
      user_one_subject_id = UUID.uuid4()

      {:ok, user} =
        User.create_or_update(user_one_subject_id, %{
          subject_id: user_one_subject_id,
          email: "blahblahblah@blah.com",
          name: "Blah Blah"
        })

      [user: user]
    end

    test "public users cannot view or edit organizations", %{public_conn: conn, user: user} do
      assert {:error,
              {
                :redirect,
                %{
                  to: "/auth/auth0?prompt=login&error_message=Unauthorized"
                }
              }} = live(conn, @url_path)
    end
  end

  describe "curator users access" do
    setup do
      user_one_subject_id = UUID.uuid4()
      user_two_subject_id = UUID.uuid4()

      {:ok, user1} =
        User.create_or_update(user_one_subject_id, %{
          subject_id: user_one_subject_id,
          email: "blah@blah.com",
          name: "Blah"
        })

      {:ok, user2} =
        User.create_or_update(user_two_subject_id, %{
          subject_id: user_two_subject_id,
          email: "foo@foo.com",
          name: "Foo"
        })

      [user1: user1, user2: user2]
    end

    test "curators can view all the users", %{curator_conn: conn} do
      assert {:ok, view, html} = live(conn, @url_path)
    end

    test "all users are presented in the users table", %{curator_conn: conn, user1: user1, user2: user2} do
      assert {:ok, view, html} = live(conn, @url_path)
      users = get_texts(html, ".users-table__cell--email")
      assert Enum.member?(users, "foo@foo.com")
      assert Enum.member?(users, "blah@blah.com")
    end
  end
end
