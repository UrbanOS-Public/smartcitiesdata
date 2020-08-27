defmodule AndiWeb.EditOrganizationLiveViewTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.ConnCase

  @moduletag shared_data_connection: true

  import Checkov
  import Phoenix.LiveViewTest
  import Andi, only: [instance_name: 0]
  import SmartCity.Event, only: [organization_update: 0]
  import SmartCity.TestHelper, only: [eventually: 1, eventually: 3]

  import FlokiHelpers,
    only: [
      get_value: 2,
      get_text: 2,
      find_elements: 2
    ]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Organizations
  alias Andi.Services.OrgStore

  @url_path "/organizations/"

  describe "create new organization" do
    setup do
      smrt_org = TDG.create_organization([])
      [smrt_org: smrt_org]
    end

    test "generate orgName from org title", %{conn: conn, smrt_org: smrt_org} do
      {:ok, andi_organization} = Organizations.update(smrt_org)

      assert {:ok, view, html} = live(conn, @url_path <> andi_organization.id)

      form_data = %{
        "orgTitle" => "Cam Org"
      }

      render_change(view, "validate", %{"form_data" => form_data, "_target" => ["form_data", "orgTitle"]})
      html = render(view)

      value = get_value(html, "#form_data_orgName")

      assert value == "cam_org"
    end

    test "validation is only triggered for new organizations", %{conn: conn} do
      smrt_organization = TDG.create_organization(%{orgName: "original_org_name"})
      Brook.Event.send(instance_name(), organization_update(), __MODULE__, smrt_organization)

      eventually(
        fn ->
          assert {:ok, nil} != OrgStore.get(smrt_organization.id)
        end,
        1_000,
        30
      )

      assert {:ok, view, html} = live(conn, @url_path <> smrt_organization.id)

      form_data = %{"orgTitle" => "some new org title", "orgName" => "original_org_name"}

      html = render_change(view, "validate", %{"form_data" => form_data, "_target" => ["form_data", "orgTitle"]})

      value = get_value(html, "#form_data_orgName")

      assert value == "original_org_name"
    end

    data_test "org title #{title} generates org name #{org_name}", %{conn: conn, smrt_org: smrt_org} do
      {:ok, organization} = Organizations.update(smrt_org)

      assert {:ok, view, html} = live(conn, @url_path <> organization.id)

      form_data = %{"orgTitle" => title}

      html = render_change(view, "validate", %{"form_data" => form_data, "_target" => ["form_data", "orgTitle"]})

      assert get_value(html, "#form_data_orgName") == org_name

      where([
        [:title, :org_name],
        ["title with spaces", "title_with_spaces"],
        ["titl3! W@th sp#ci@l ch@rs", "titl3_wth_spcil_chrs"],
        ["ALL CAPS TITLE", "all_caps_title"]
      ])
    end

    data_test "#{title} generating an empty data name is invalid", %{conn: conn, smrt_org: smrt_org} do
      {:ok, organization} = Organizations.update(smrt_org)

      assert {:ok, view, html} = live(conn, @url_path <> organization.id)

      form_data = %{"orgTitle" => title}

      render_change(view, "validate", %{"form_data" => form_data, "_target" => ["form_data", "orgTitle"]})
      html = render(view)

      assert get_value(html, "#form_data_orgName") == ""
      refute Enum.empty?(find_elements(html, "#orgName-error-msg"))

      where(title: ["", "!@#$%"])
    end
  end

  describe "edit organization form data" do
    data_test "required #{field} field displays proper error message", %{conn: conn} do
      smrt_org = TDG.create_organization(%{})

      {:ok, _} = Organizations.update(smrt_org)

      assert {:ok, view, html} = live(conn, @url_path <> smrt_org.id)

      html = render_change(view, :validate, %{"form_data" => form_data})

      assert get_text(html, "##{field}-error-msg") == expected_error_message

      where([
        [:field, :form_data, :expected_error_message],
        [:orgTitle, %{"orgTitle" => ""}, "Please enter a valid organization title."],
        [:description, %{"description" => ""}, "Please enter a valid description."],
        [:orgName, %{"orgName" => ""}, "Please enter a valid organization name."]
      ])
    end

    test "error message is cleared when form is updated", %{conn: conn} do
      smrt_org = TDG.create_organization(%{})
      {:ok, _} = Organizations.update(smrt_org)

      assert {:ok, view, html} = live(conn, @url_path <> smrt_org.id)

      form_data = %{"description" => ""}

      html = render_change(view, :validate, %{"form_data" => form_data})

      assert get_text(html, "#description-error-msg") == "Please enter a valid description."

      updated_form_data = %{"description" => "this is the description"}

      html = render_change(view, :validate, %{"form_data" => updated_form_data})

      assert get_text(html, "#description-error-msg") == ""
    end
  end

  test "save button sends brook event", %{conn: conn} do
    smrt_org = TDG.create_organization(%{})
    {:ok, _} = Organizations.update(smrt_org)

    assert {:ok, view, html} = live(conn, @url_path <> smrt_org.id)

    render_click(view, "save", nil)

    eventually(fn ->
      assert {:ok, nil} != OrgStore.get(smrt_org.id)
    end)
  end

  test "cancel button returns user to organizations list page", %{conn: conn} do
    smrt_org = TDG.create_organization(%{})
    {:ok, _} = Organizations.update(smrt_org)

    assert {:ok, view, html} = live(conn, @url_path <> smrt_org.id)

    render_click(view, "cancel-edit", nil)

    assert_redirect(view, "/organizations")
  end
end
