defmodule AndiWeb.EditUserLiveViewTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  import AndiWeb.Test.PublicAccessCase

  @moduletag shared_data_connection: true

  import Phoenix.LiveViewTest
  import SmartCity.TestHelper, only: [eventually: 1]

  import FlokiHelpers,
    only: [
      get_value: 2,
      find_elements: 2
    ]

  alias Andi.Schemas.User
  alias Andi.InputSchemas.Organizations

  @url_path "/user/"

  describe "curator user access" do
    setup %{public_subject: public_subject} do
      {:ok, public_user} = Andi.Schemas.User.create_or_update(public_subject, %{email: "bob@example.com"})

      org_one = Organizations.create()
      org_two = Organizations.create()

      {:ok, _} = User.associate_with_organization(public_subject, org_one.id)
      {:ok, _} = User.associate_with_organization(public_subject, org_two.id)

      [public_user: public_user]
    end

    test "curators can view users and associated orgs", %{curator_conn: curator_conn, public_user: public_user} do
      assert {:ok, view, html} = live(curator_conn, @url_path <> public_user.id)
    end

    test "curators can see the users email as readonly", %{curator_conn: curator_conn, public_user: public_user} do
      assert {:ok, view, html} = live(curator_conn, @url_path <> public_user.id)
      email = get_value(html, "#form_data_email")
      assert email == "bob@example.com"
    end

    test "curators can see organizations associated with the user", %{curator_conn: curator_conn, public_user: public_user} do
      assert {:ok, view, html} = live(curator_conn, @url_path <> public_user.id)

      orgs = find_elements(html, ".organizations-table__tr")
      assert length(orgs) == 2
    end
  end
end
