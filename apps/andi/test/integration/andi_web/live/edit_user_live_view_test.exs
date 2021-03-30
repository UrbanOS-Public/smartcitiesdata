defmodule AndiWeb.EditUserLiveViewTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase

  @moduletag shared_data_connection: true

  import Phoenix.LiveViewTest

  import FlokiHelpers,
    only: [
      get_value: 2,
      find_elements: 2
    ]

  alias Andi.Schemas.User
  alias Andi.InputSchemas.Organizations

  @url_path "/user/"

  describe "public user access" do
    setup do
      subject_id = Ecto.UUID.generate()
      {:ok, user} = User.create_or_update(subject_id, %{email: "test@test.com"})

      [user: user]
    end

    test "public users cannot view or edit users", %{public_conn: conn, user: user} do
      assert {:error,
              {
                :redirect,
                %{
                  to: "/auth/auth0?prompt=login&error_message=Unauthorized"
                }
              }} = live(conn, @url_path <> user.id)

      true
    end
  end

  describe "curator user access" do
    setup do
      subject_id = Ecto.UUID.generate()
      {:ok, user} = User.create_or_update(subject_id, %{email: "bob@bob.com"})

      org_one = Organizations.create()
      org_two = Organizations.create()

      {:ok, _} = User.associate_with_organization(subject_id, org_one.id)
      {:ok, _} = User.associate_with_organization(subject_id, org_two.id)

      [user: user]
    end

    test "curators can view users and associated orgs", %{curator_conn: conn, user: user} do
      assert {:ok, view, html} = live(conn, @url_path <> user.id)
    end

    test "curators can see the users email as readonly", %{curator_conn: conn, user: user} do
      assert {:ok, view, html} = live(conn, @url_path <> user.id)
      email = get_value(html, "#form_data_email")
      assert email == "bob@bob.com"
    end

    test "curators can see organizations associated with the user", %{curator_conn: conn, user: user} do
      assert {:ok, view, html} = live(conn, @url_path <> user.id)

      orgs = find_elements(html, ".organizations-table__tr")
      assert length(orgs) == 2
    end
  end
end
