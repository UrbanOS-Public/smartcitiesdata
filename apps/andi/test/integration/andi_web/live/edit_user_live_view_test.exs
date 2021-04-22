defmodule AndiWeb.EditUserLiveViewTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase

  @moduletag shared_data_connection: true

  import Checkov
  import Phoenix.LiveViewTest
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
  alias Andi.InputSchemas.Datasets
  alias Andi.Services.OrgStore

  alias Andi.Schemas.User

  @instance_name Andi.instance_name()

  @url_path "/user/"

  describe "public user access" do
    setup do
      user_one_id = Ecto.UUID.generate()
      user_one_subject_id = Ecto.UUID.generate()

      User.create_or_update(user_one_subject_id, %{id: user_one_id, email: "test@test.com"})

      smrt_org = TDG.create_organization([])
      {:ok, andi_organization} = Organizations.update(smrt_org)

      [org: andi_organization, user_one_subject_id: user_one_subject_id, user_one_id: user_one_id]
    end

    test "public users cannot view or edit organizations", %{public_conn: conn, user_one_id: user_one_id} do
      assert {:error,
              {
                :redirect,
                %{
                  to: "/auth/auth0?prompt=login&error_message=Unauthorized"
                }
              }} = live(conn, @url_path <> user_one_id)
    end
  end

  describe "curator organization access" do
    setup do
      user_one_id = Ecto.UUID.generate()
      user_one_subject_id = Ecto.UUID.generate()

      User.create_or_update(user_one_subject_id, %{id: user_one_id, email: "test@test.com"})

      smrt_org = TDG.create_organization([])
      {:ok, andi_organization} = Organizations.update(smrt_org)

      [org: andi_organization, user_one_subject_id: user_one_subject_id, user_one_id: user_one_id]
    end

    test "curators can view and edit organizations", %{curator_conn: conn, user_one_id: user_one_id} do
      assert {:ok, view, html} = live(conn, @url_path <> user_one_id)
    end
  end

  # describe "create new organization" do
  #   setup do
  #     smrt_org = TDG.create_organization([])
  #     [smrt_org: smrt_org]
  #   end

  #   test "generate orgName from org title", %{conn: conn, smrt_org: smrt_org} do
  #     {:ok, andi_organization} = Organizations.update(smrt_org)

  #     assert {:ok, view, html} = live(conn, @url_path <> andi_organization.id)

  #     form_data = %{
  #       "orgTitle" => "Cam Org"
  #     }

  #     render_change(view, "validate", %{"form_data" => form_data, "_target" => ["form_data", "orgTitle"]})
  #     html = render(view)

  #     value = get_value(html, "#form_data_orgName")

  #     assert value == "cam_org"
  #   end

  #   test "validation is only triggered for new organizations", %{conn: conn} do
  #     smrt_organization = TDG.create_organization(%{orgName: "original_org_name"})
  #     Brook.Event.send(@instance_name, organization_update(), __MODULE__, smrt_organization)

  #     eventually(
  #       fn ->
  #         assert {:ok, nil} != OrgStore.get(smrt_organization.id)
  #       end,
  #       1_000,
  #       30
  #     )

  #     assert {:ok, view, html} = live(conn, @url_path <> smrt_organization.id)

  #     form_data = %{"orgTitle" => "some new org title", "orgName" => "original_org_name"}

  #     html = render_change(view, "validate", %{"form_data" => form_data, "_target" => ["form_data", "orgTitle"]})

  #     value = get_value(html, "#form_data_orgName")

  #     assert value == "original_org_name"
  #   end

  #   test "cannot create an org with a non unique org name", %{conn: conn} do
  #     org = TDG.create_organization(%{orgName: "some_great_org_name"})
  #     Organizations.update(org)

  #     non_unique_org = Organizations.create()

  #     assert {:ok, view, html} = live(conn, @url_path <> non_unique_org.id)

  #     form_data = %{"orgTitle" => "some great org name"}

  #     render_change(view, "validate", %{"form_data" => form_data, "_target" => ["form_data", "orgTitle"]})

  #     html = render_change(view, "validate_unique_org_name")

  #     assert "Error: organization name already exists" == get_text(html, "#orgName-error-msg")
  #   end

  #   test "org a names longer than the threshold are truncated", %{conn: conn} do
  #     org = TDG.create_organization(%{orgName: "some_great_org_name"})
  #     Organizations.update(org)

  #     non_unique_org = Organizations.create()

  #     assert {:ok, view, html} = live(conn, @url_path <> non_unique_org.id)

  #     form_data = %{"orgTitle" => "Praesent nec arcu eget est porttitor et. Ave."}

  #     render_change(view, "validate", %{"form_data" => form_data, "_target" => ["form_data", "orgTitle"]})

  #     html = render(view)

  #     value = get_value(html, "#form_data_orgName")

  #     assert value == "praesent_nec_arcu_eget_est_porttitor_et"
  #   end

  #   data_test "org title #{title} generates org name #{org_name}", %{conn: conn, smrt_org: smrt_org} do
  #     {:ok, organization} = Organizations.update(smrt_org)

  #     assert {:ok, view, html} = live(conn, @url_path <> organization.id)

  #     form_data = %{"orgTitle" => title}

  #     html = render_change(view, "validate", %{"form_data" => form_data, "_target" => ["form_data", "orgTitle"]})

  #     assert get_value(html, "#form_data_orgName") == org_name

  #     where([
  #       [:title, :org_name],
  #       ["title with spaces", "title_with_spaces"],
  #       ["titl3! W@th sp#ci@l ch@rs", "titl3_wth_spcil_chrs"],
  #       ["ALL CAPS TITLE", "all_caps_title"]
  #     ])
  #   end

  #   data_test "#{title} generating an empty data name is invalid", %{conn: conn, smrt_org: smrt_org} do
  #     {:ok, organization} = Organizations.update(smrt_org)

  #     assert {:ok, view, html} = live(conn, @url_path <> organization.id)

  #     form_data = %{"orgTitle" => title}

  #     render_change(view, "validate", %{"form_data" => form_data, "_target" => ["form_data", "orgTitle"]})
  #     html = render(view)

  #     assert get_value(html, "#form_data_orgName") == ""
  #     refute Enum.empty?(find_elements(html, "#orgName-error-msg"))

  #     where(title: ["", "!@#$%"])
  #   end
  # end

  # describe "edit organization form data" do
  #   data_test "required #{field} field displays proper error message", %{conn: conn} do
  #     smrt_org = TDG.create_organization(%{})

  #     {:ok, _} = Organizations.update(smrt_org)

  #     assert {:ok, view, html} = live(conn, @url_path <> smrt_org.id)

  #     html = render_change(view, :validate, %{"form_data" => form_data})

  #     assert get_text(html, "##{field}-error-msg") == expected_error_message

  #     where([
  #       [:field, :form_data, :expected_error_message],
  #       [:orgTitle, %{"orgTitle" => ""}, "Please enter a valid organization title."],
  #       [:description, %{"description" => ""}, "Please enter a valid description."],
  #       [:orgName, %{"orgName" => ""}, "Please enter a valid organization name."]
  #     ])
  #   end

  #   test "error message is cleared when form is updated", %{conn: conn} do
  #     smrt_org = TDG.create_organization(%{})
  #     {:ok, _} = Organizations.update(smrt_org)

  #     assert {:ok, view, html} = live(conn, @url_path <> smrt_org.id)

  #     form_data = %{"description" => ""}

  #     html = render_change(view, :validate, %{"form_data" => form_data})

  #     assert get_text(html, "#description-error-msg") == "Please enter a valid description."

  #     updated_form_data = %{"description" => "this is the description"}

  #     html = render_change(view, :validate, %{"form_data" => updated_form_data})

  #     assert get_text(html, "#description-error-msg") == ""
  #   end
  # end

  # describe "save and cancel buttons" do
  #   test "save button sends brook event and presents user with save success modal", %{conn: conn} do
  #     smrt_org = TDG.create_organization(%{})
  #     {:ok, _} = Organizations.update(smrt_org)

  #     assert {:ok, view, html} = live(conn, @url_path <> smrt_org.id)

  #     html = render_click(view, "save", %{})

  #     eventually(
  #       fn ->
  #         assert {:ok, nil} != OrgStore.get(smrt_org.id)
  #       end,
  #       1000,
  #       30
  #     )

  #     refute Enum.empty?(find_elements(html, ".publish-success-modal--visible"))
  #   end

  #   test "save button shows snackbar when user saves invalid changes", %{conn: conn} do
  #     smrt_org = TDG.create_organization(%{})
  #     {:ok, _} = Organizations.update(smrt_org)

  #     assert {:ok, view, html} = live(conn, @url_path <> smrt_org.id)

  #     invalid_form_data = %{"description" => ""}
  #     html = render_click(view, "validate", %{"form_data" => invalid_form_data})
  #     refute Enum.empty?(find_elements(html, "#description-error-msg"))

  #     html = render_click(view, "save", %{})

  #     refute Enum.empty?(find_elements(html, "#snackbar"))
  #   end

  #   test "cancel button returns user to organizations list page", %{conn: conn} do
  #     smrt_org = TDG.create_organization(%{})
  #     {:ok, _} = Organizations.update(smrt_org)

  #     assert {:ok, view, html} = live(conn, @url_path <> smrt_org.id)

  #     render_click(view, "cancel-edit", %{})

  #     assert_redirect(view, "/organizations")
  #   end

  #   data_test "#{event} event shows unsaved changes modal before redirect when changes have been made", %{conn: conn} do
  #     smrt_org = TDG.create_organization(%{})
  #     {:ok, _} = Organizations.update(smrt_org)

  #     assert {:ok, view, html} = live(conn, @url_path <> smrt_org.id)
  #     form_data = %{"description" => "updated description"}
  #     render_change(view, "validate", %{"form_data" => form_data})

  #     refute Enum.empty?(find_elements(html, ".unsaved-changes-modal--hidden"))

  #     html = render_click(view, event, %{})

  #     refute Enum.empty?(find_elements(html, ".unsaved-changes-modal--visible"))

  #     where(event: ["cancel-edit", "show-organizations", "show-datasets"])
  #   end
  # end

  # describe "harvested datasets table" do
  #   setup do
  #     dataset1 = TDG.create_dataset(%{})
  #     dataset2 = TDG.create_dataset(%{})
  #     dataset3 = TDG.create_dataset(%{})
  #     dataset4 = TDG.create_dataset(%{})

  #     {:ok, org} = TDG.create_organization(%{}) |> Organizations.update()

  #     %{dataTitle: dataset1.business.dataTitle, datasetId: dataset1.id, orgId: org.id} |> Organizations.update_harvested_dataset()
  #     %{dataTitle: dataset2.business.dataTitle, datasetId: dataset2.id, orgId: org.id} |> Organizations.update_harvested_dataset()
  #     %{dataTitle: dataset3.business.dataTitle, datasetId: dataset3.id, orgId: UUID.uuid4()} |> Organizations.update_harvested_dataset()
  #     %{dataTitle: dataset4.business.dataTitle, datasetId: dataset4.id, orgId: org.id} |> Organizations.update_harvested_dataset()

  #     [
  #       org: org,
  #       dataset1: dataset1,
  #       dataset2: dataset2,
  #       dataset3: dataset3,
  #       dataset4: dataset4
  #     ]
  #   end

  #   test "shows all harvested datasets associated with a given organization", %{
  #     conn: conn,
  #     org: org,
  #     dataset1: dataset1,
  #     dataset2: dataset2,
  #     dataset3: dataset3
  #   } do
  #     assert {:ok, view, html} = live(conn, @url_path <> org.id)

  #     get_text(html, ".organizations-table__tr")

  #     assert get_text(html, ".organizations-table__tr") =~ dataset1.business.dataTitle
  #     assert get_text(html, ".organizations-table__tr") =~ dataset2.business.dataTitle
  #     refute get_text(html, ".organizations-table__tr") =~ dataset3.business.dataTitle
  #   end

  #   test "include checkbox is present for all datasets", %{conn: conn, org: org} do
  #     assert {:ok, view, html} = live(conn, @url_path <> org.id)

  #     assert length(Floki.attribute(html, ".organizations-table__checkbox--input", "checked")) == 3
  #   end

  #   test "unselecting include for a dataset sends a dataset delete event and updates the include field in the havested table", %{
  #     conn: conn,
  #     org: org,
  #     dataset4: dataset4
  #   } do
  #     assert {:ok, view, html} = live(conn, @url_path <> org.id)

  #     Organizations.update_harvested_dataset_include(dataset4.id, true)

  #     assert %{include: true} = Organizations.get_harvested_dataset(dataset4.id)

  #     render_change(view, "toggle_include", %{"id" => dataset4.id})

  #     assert %{include: false} = Organizations.get_harvested_dataset(dataset4.id)

  #     eventually(fn ->
  #       assert nil == Datasets.get(dataset4.id)
  #     end)
  #   end

  #   test "selecting include for a datasets updates the include field in the harvested table", %{conn: conn, org: org, dataset1: dataset1} do
  #     assert {:ok, view, html} = live(conn, @url_path <> org.id)

  #     Organizations.update_harvested_dataset_include(dataset1.id, false)

  #     assert %{include: false} = Organizations.get_harvested_dataset(dataset1.id)

  #     render_change(view, "toggle_include", %{"id" => dataset1.id})

  #     assert %{include: true} = Organizations.get_harvested_dataset(dataset1.id)
  #   end
  # end
end
