defmodule AndiWeb.EditUserLiveViewTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase

  @moduletag shared_data_connection: true

  use Placebo
  import Phoenix.LiveViewTest
  import SmartCity.Event, only: [
    organization_update: 0,
    user_organization_associate: 0,
    user_organization_disassociate: 0
  ]
  import SmartCity.TestHelper, only: [eventually: 1]

  import FlokiHelpers,
    only: [
      get_value: 2,
      get_all_select_options: 2,
      find_elements: 2
    ]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Organizations
  alias Andi.Schemas.AuditEvent
  alias Andi.Schemas.AuditEvents
  alias Andi.Services.Auth0Management

  alias Andi.Schemas.User

  @instance_name Andi.instance_name()

  @url_path "/user/"

  describe "public user access" do
    setup do
      user_one_subject_id = UUID.uuid4()

      {:ok, user} =
        User.create_or_update(user_one_subject_id, %{
          subject_id: user_one_subject_id,
          email: "blahblahblah@blah.com",
          name: "Someone"
        })

      smrt_org = TDG.create_organization([])
      {:ok, andi_organization} = Organizations.update(smrt_org)

      [org: andi_organization, user: user]
    end

    test "public users cannot view or edit users", %{public_conn: conn, user: user} do
      assert {:error,
              {
                :redirect,
                %{
                  to: "/auth/auth0?prompt=login&error_message=Unauthorized"
                }
              }} = live(conn, @url_path <> user.id)
    end
  end

  describe "curator user access" do
    setup do
      user_one_subject_id = UUID.uuid4()

      {:ok, user} =
        User.create_or_update(user_one_subject_id, %{
          subject_id: user_one_subject_id,
          email: "blah@blah.com",
          name: "Someone"
        })

      org1 = TDG.create_organization(%{orgTitle: "Awesome Title", orgName: "awesome_title"})

      Brook.Event.send(@instance_name, organization_update(), __MODULE__, org1)

      allow(Auth0Management.get_roles(),
        return: {:ok, [%{"description" => "Dataset Curator", "id" => "rol_OQaxdo38yewzqWR0", "name" => "Curator"}]},
        meck_options: [:passthrough]
      )

      allow(Auth0Management.get_user_roles(any()),
        return: {:ok, [%{"description" => "Dataset Curator", "id" => "rol_OQaxdo38yewzqWR0", "name" => "Curator"}]},
        meck_options: [:passthrough]
      )

      [org: org1, user: user]
    end

    test "curators can view and edit users", %{curator_conn: conn, user: user} do
      assert {:ok, view, html} = live(conn, @url_path <> user.id)
    end

    test "curators can read user email", %{curator_conn: conn, user: user} do
      assert {:ok, view, html} = live(conn, @url_path <> user.id)

      assert user.email == get_value(html, "#form_data_email")
    end

    test "curators can read user roles", %{curator_conn: conn, user: user} do
      assert {:ok, view, html} = live(conn, @url_path <> user.id)

      assert [
               {"Please select a role", ""},
               {"Dataset Curator", "rol_OQaxdo38yewzqWR0"}
             ] = get_all_select_options(html, "#form_data_role")
    end

    test "curators can associate orgs to users", %{curator_conn: conn, user: user, org: org} do
      assert {:ok, view, html} = live(conn, @url_path <> user.id)
      org_id = org.id

      eventually(fn ->
        assert [{"Please select an organization", ""}, {"Awesome Title", org_id} | rest] =
                 get_all_select_options(html, "#organiation_org_id")
      end)

      render_change(view, "associate", %{"organiation" => %{"org_id" => org_id}})

      eventually(fn ->
        user_subject_id = user.subject_id
        user = User.get_by_subject_id(user.subject_id)

        assert [%{id: org_id}] = user.organizations
        assert [ %AuditEvent{event: %{"subject_id" => ^user_subject_id, "org_id" => ^org_id}} | _ ] = AuditEvents.get_all_of_type(user_organization_associate())
      end)
    end

    test "curators can disassociate an organization from a user", %{curator_conn: conn, user: user, org: org} do
      assert {:ok, view, html} = live(conn, @url_path <> user.id)
      org_id = org.id

      # Create another org
      org2 = TDG.create_organization(%{orgTitle: "another awesome org", orgName: "another_awesome_org_title"})

      Brook.Event.send(@instance_name, organization_update(), __MODULE__, org2)

      org2_id = org2.id

      # Associate to user
      render_change(view, "associate", %{"organiation" => %{"org_id" => org_id}})
      render_change(view, "associate", %{"organiation" => %{"org_id" => org2_id}})

      eventually(fn ->
        user = User.get_by_subject_id(user.subject_id)

        assert [%{id: org_id}, %{id: org2_id}] = user.organizations
      end)

      # Disassociate an org from a user
      send(view.pid, {:disassociate_org, org2_id})

      eventually(fn ->
        user_subject_id = user.subject_id
        user = User.get_by_subject_id(user_subject_id)

        assert [%{id: org_id}] = user.organizations

        assert [ %AuditEvent{event: %{"subject_id" => ^user_subject_id, "org_id" => ^org2_id}} | _ ] = AuditEvents.get_all_of_type(user_organization_disassociate())
      end)
    end
  end

  describe "curator user roles" do
    setup do
      user_one_subject_id = UUID.uuid4()

      {:ok, user} =
        User.create_or_update(user_one_subject_id, %{
          subject_id: user_one_subject_id,
          email: "blah@blah.com",
          name: "Someone"
        })

      org1 = TDG.create_organization(%{orgTitle: "Awesome Title", orgName: "awesome_title"})

      Brook.Event.send(@instance_name, organization_update(), __MODULE__, org1)

      allow(Auth0Management.get_roles(),
        return: {:ok, [%{"description" => "Dataset Curator", "id" => "rol_OQaxdo38yewzqWR0", "name" => "Curator"}]},
        meck_options: [:passthrough]
      )

      allow(Auth0Management.assign_user_role(any(), any()),
        return: {:ok, any()},
        meck_options: [:passthrough]
      )

      allow(Auth0Management.delete_user_role(any(), any()),
        return: {:ok, any()},
        meck_options: [:passthrough]
      )

      [org: org1, user: user]
    end

    test "curators can view users current roles", %{curator_conn: conn, user: user} do
      allow(Auth0Management.get_user_roles(any()),
        return: {:ok, [%{"description" => "Dataset Curator", "id" => "rol_OQaxdo38yewzqWR0", "name" => "Curator"}]},
        meck_options: [:passthrough]
      )

      assert {:ok, view, html} = live(conn, @url_path <> user.id)

      assert length(find_elements(html, ".roles-table__tr")) == 1
    end

    test "curators can add roles to users", %{curator_conn: conn, user: user} do
      allow(Auth0Management.get_user_roles(any()),
        return: {:ok, []},
        meck_options: [:passthrough]
      )

      assert {:ok, view, html} = live(conn, @url_path <> user.id)

      assert Enum.empty?(find_elements(html, ".roles-table__tr"))

      allow(Auth0Management.get_user_roles(any()),
        return: {:ok, [%{"description" => "Dataset Curator", "id" => "rol_OQaxdo38yewzqWR0", "name" => "Curator"}]},
        meck_options: [:passthrough]
      )

      # add role to user
      html = render_change(view, "add-role", %{"selected-role" => "rol_OQaxdo38yewzqWR0"})

      assert length(find_elements(html, ".roles-table__tr")) == 1
    end

    test "curators can remove roles from users", %{curator_conn: conn, user: user} do
      allow(Auth0Management.get_user_roles(any()),
        return: {:ok, [%{"description" => "Dataset Curator", "id" => "rol_OQaxdo38yewzqWR0", "name" => "Curator"}]},
        meck_options: [:passthrough]
      )

      assert {:ok, view, html} = live(conn, @url_path <> user.id)

      assert length(find_elements(html, ".roles-table__tr")) == 1

      allow(Auth0Management.get_user_roles(any()),
        return: {:ok, []},
        meck_options: [:passthrough]
      )

      # remove role
      send(view.pid, {:remove_role, "rol_OQaxdo38yewzqWR0"})

      html = render(view)

      assert Enum.empty?(find_elements(html, ".roles-table__tr"))
    end
  end
end
