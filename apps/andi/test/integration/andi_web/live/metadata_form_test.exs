defmodule AndiWeb.MetadataFormTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  use Placebo

  import Checkov

  alias Andi.Services.DatasetStore
  alias Andi.Services.OrgStore

  @moduletag shared_data_connection: true

  import Phoenix.LiveViewTest
  import SmartCity.Event, only: [dataset_update: 0, organization_update: 0]
  import SmartCity.TestHelper, only: [eventually: 1, eventually: 3]

  import FlokiHelpers,
    only: [
      get_attributes: 3,
      get_value: 2,
      get_values: 2,
      get_select: 2,
      get_select_first_option: 2,
      get_all_select_options: 2,
      get_text: 2,
      find_elements: 2
    ]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Datasets
  alias Andi.Schemas.User
  alias Andi.InputSchemas.Datasets.Dataset
  alias Andi.InputSchemas.InputConverter

  @instance_name Andi.instance_name()

  @endpoint AndiWeb.Endpoint
  @url_path "/datasets/"

  setup %{curator_subject: curator_subject}do
    {:ok, curator_user} = Andi.Schemas.User.create_or_update(curator_subject, %{email: "bob42@example.com"})

    [curator_user: curator_user]
  end

  describe "create new dataset" do
    setup do
      blank_dataset = %Dataset{id: UUID.uuid4(), technical: %{}, business: %{}}
      [blank_dataset: blank_dataset]
    end

    test "generate dataName from data title", %{conn: conn, blank_dataset: blank_dataset} do
      {:ok, andi_dataset} = Datasets.update(blank_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> andi_dataset.id)
      metadata_view = find_live_child(view, "metadata_form_editor")

      form_data = %{
        "dataTitle" => "simpledatatitle"
      }

      render_change(metadata_view, "validate", %{"form_data" => form_data, "_target" => ["form_data", "dataTitle"]})
      html = render(metadata_view)

      value = get_value(html, "#form_data_dataName")

      assert value == "simpledatatitle"
    end

    test "validation is only triggered for new datasets", %{conn: conn, curator_user: curator_user} do
      {:ok, dataset} = Datasets.create(curator_user)
      |> Datasets.update(%{technical: %{dataName: "original name"}, submission_status: :published})

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_live_child(view, "metadata_form_editor")

      form_data = %{"dataTitle" => "simpledatatitle", "dataName" => dataset.technical.dataName}

      render_change(metadata_view, "validate", %{"form_data" => form_data, "_target" => ["form_data", "dataTitle"]})
      html = render(metadata_view)

      value = get_value(html, "#form_data_dataName")

      assert value == "original name"
    end

    data_test "data title #{title} generates data name #{data_name}", %{conn: conn, blank_dataset: blank_dataset} do
      {:ok, dataset} = Datasets.update(blank_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_live_child(view, "metadata_form_editor")

      form_data = %{"dataTitle" => title}

      render_change(metadata_view, "validate", %{"form_data" => form_data, "_target" => ["form_data", "dataTitle"]})
      html = render(metadata_view)

      assert get_value(html, "#form_data_dataName") == data_name

      where([
        [:title, :data_name],
        ["title with spaces", "title_with_spaces"],
        ["titl3! W@th sp#ci@l ch@rs", "titl3_wth_spcil_chrs"],
        ["ALL CAPS TITLE", "all_caps_title"]
      ])
    end

    data_test "#{title} generating an empty data name is invalid", %{conn: conn, blank_dataset: blank_dataset} do
      {:ok, dataset} = Datasets.update(blank_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_live_child(view, "metadata_form_editor")

      form_data = %{"dataTitle" => title}

      render_change(metadata_view, "validate", %{"form_data" => form_data, "_target" => ["form_data", "dataTitle"]})
      html = render(metadata_view)

      assert get_value(html, "#form_data_dataName") == ""
      refute Enum.empty?(find_elements(html, "#dataName-error-msg"))

      where(title: ["", "!@#$%"])
    end

    test "organization dropdown is populated with all organizations in the system", %{conn: conn, blank_dataset: blank_dataset} do
      {:ok, dataset} = Datasets.update(blank_dataset)

      org1 = TDG.create_organization(%{orgTitle: "Awesome Title", orgName: "awesome_title"})
      org2 = TDG.create_organization(%{orgTitle: "Very Readable", orgName: "very_readable"})

      Brook.Event.send(@instance_name, organization_update(), __MODULE__, org1)
      Brook.Event.send(@instance_name, organization_update(), __MODULE__, org2)

      eventually(fn ->
        assert OrgStore.get(org1.id) != {:ok, nil}
        assert OrgStore.get(org2.id) != {:ok, nil}
      end)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_live_child(view, "metadata_form_editor")

      assert {"", ["Please select an organization"]} == get_select_first_option(html, "#form_data_orgId")

      form_data = %{"dataName" => "data_title", "orgId" => org2.id}

      html = render_change(metadata_view, "validate", %{"form_data" => form_data, "_target" => ["form_data", "orgId"]})

      assert "very_readable__data_title" == get_value(html, "#form_data_systemName")
      assert {org2.id, "Very Readable"} == get_select(html, "#form_data_orgId")
    end

    test "updating data title allows common data name across different orgs", %{conn: conn} do
      existing_dataset = TDG.create_dataset(%{technical: %{orgName: "kevino", dataName: "camido", systemName: "kevino__camino"}})
      {:ok, _} = Datasets.update(existing_dataset)

      new_dataset = TDG.create_dataset(%{technical: %{orgName: "carrabino", dataName: "blah", systemName: "carrabino__blah"}})
      {:ok, _} = Datasets.update(new_dataset)

      assert {:ok, view, _} = live(conn, @url_path <> new_dataset.id)
      metadata_view = find_live_child(view, "metadata_form_editor")

      form_data = %{"dataTitle" => "camido"}

      render_change(metadata_view, "validate", %{"form_data" => form_data, "_target" => ["form_data", "dataTitle"]})
      render(metadata_view)
      render_change(metadata_view, "validate_system_name", %{})
      html = render(metadata_view)

      assert Enum.empty?(find_elements(html, "#dataName-error-msg"))
    end

    test "updating data title adds error when data name exists within same org", %{conn: conn} do
      existing_dataset = TDG.create_dataset(%{technical: %{orgName: "kevino", dataName: "camino", systemName: "kevino__camino"}})
      {:ok, _} = Datasets.update(existing_dataset)

      new_dataset = TDG.create_dataset(%{technical: %{orgName: "kevino", dataName: "harharhar", systemName: "kevino__harharhar"}})
      {:ok, new_andi_dataset} = Datasets.update(new_dataset)

      assert {:ok, view, _} = live(conn, @url_path <> new_dataset.id)
      metadata_view = find_live_child(view, "metadata_form_editor")

      form_data = %{"dataTitle" => "camino", "orgName" => new_andi_dataset.technical.orgName, "datasetId" => new_andi_dataset.id}

      render_change(metadata_view, "validate", %{"form_data" => form_data, "_target" => ["form_data", "dataTitle"]})
      render(metadata_view)
      render_change(metadata_view, "validate_system_name", %{})
      html = render(metadata_view)

      refute Enum.empty?(find_elements(html, "#dataName-error-msg"))
    end

    test "changing org retriggers data_name validation", %{conn: conn} do
      existing_dataset = TDG.create_dataset(%{technical: %{orgName: "kevino", dataName: "camino", systemName: "kevino__camino"}})
      {:ok, _} = Datasets.update(existing_dataset)

      new_dataset = TDG.create_dataset(%{technical: %{orgName: "benjino", dataName: "camino", systemName: "benjino__camino"}})
      {:ok, _} = Datasets.update(new_dataset)

      org = TDG.create_organization(%{orgTitle: "kevin org", orgName: "kevino"})
      Brook.Event.send(@instance_name, organization_update(), __MODULE__, org)
      eventually(fn -> OrgStore.get(org.id) != {:ok, nil} end)

      assert {:ok, view, _} = live(conn, @url_path <> new_dataset.id)
      metadata_view = find_live_child(view, "metadata_form_editor")

      form_data = %{"dataTitle" => "camino", "orgName" => new_dataset.technical.orgName}

      render_change(metadata_view, "validate", %{"form_data" => form_data, "_target" => ["form_data", "dataTitle"]})
      render(metadata_view)
      render_change(metadata_view, "validate_system_name", %{})
      html = render(metadata_view)

      assert Enum.empty?(find_elements(html, "#dataName-error-msg"))

      form_data = %{"dataTitle" => "camino", "orgId" => org.id}

      render_change(metadata_view, "validate", %{"form_data" => form_data, "_target" => ["form_data", "orgId"]})
      html = render(metadata_view)

      refute Enum.empty?(find_elements(html, "#dataName-error-msg"))
    end
  end

  describe "enter form data" do
    test "display Level of Access as public when private is false", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{technical: %{private: false}})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)
      assert {"false", "Public"} = get_select(html, ".metadata-form__level-of-access")
    end

    test "display Level of Access as private when private is true", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{technical: %{private: true}})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)

      assert {"true", "Private"} = get_select(html, ".metadata-form__level-of-access")
    end

    test "the default language is set to english", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)

      assert {"english", "English"} = get_select(html, ".metadata-form__language")
    end

    test "the language is set to spanish", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{business: %{language: "spanish"}})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert {"spanish", "Spanish"} = get_select(html, ".metadata-form__language")
    end

    test "the language is changed from english to spanish", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_live_child(view, "metadata_form_editor")

      form_data = %{"language" => "spanish"}

      html = render_change(metadata_view, :validate, %{"form_data" => form_data})

      assert {"spanish", "Spanish"} = get_select(html, ".metadata-form__language")
    end

    data_test "benefit rating is set to '#{label}' (#{inspect(value)})", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{business: %{benefitRating: value}})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert {to_string(value), label} == get_select(html, ".metadata-form__benefit-rating")

      where([
        [:value, :label],
        [0.0, "Low"],
        [0.5, "Medium"],
        [1.0, "High"]
      ])
    end

    data_test "risk rating is set to '#{label}' (#{inspect(value)})", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{business: %{riskRating: value}})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert {to_string(value), label} == get_select(html, ".metadata-form__risk-rating")

      where([
        [:value, :label],
        [0.0, "Low"],
        [0.5, "Medium"],
        [1.0, "High"]
      ])
    end

    data_test "errors on invalid email: #{email}", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{business: %{contactEmail: email}})

      {:ok, dataset} =
        InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
        |> Datasets.save()

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_live_child(view, "metadata_form_editor")

      form_data = %{"contactEmail" => email}

      html = render_change(metadata_view, :validate, %{"form_data" => form_data})

      assert get_text(html, "#contactEmail-error-msg") == "Please enter a valid maintainer email."

      where([
        [:email],
        ["foomail.com"],
        ["kevinspace@"],
        ["kevinspace@notarealdomain"],
        ["my little address"]
      ])
    end

    data_test "does not error on valid email: #{email}", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{business: %{contactEmail: email}})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_live_child(view, "metadata_form_editor")

      form_data = %{"contactEmail" => email}

      html = render_change(metadata_view, :validate, %{"form_data" => form_data})
      assert get_text(html, "#contactEmail-error-msg") == ""

      where([
        [:email],
        ["foo@mail.com"],
        ["kevin@space.org"],
        ["my@little.gov"],
        ["test-email@email.com"]
      ])
    end

    test "adds commas between keywords", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{business: %{keywords: ["one", "two", "three"]}})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)
      [subject] = get_values(html, ".metadata-form__keywords input")

      assert subject =~ "one, two, three"
    end

    test "keywords input should show empty string if keywords is nil", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{business: %{keywords: nil}})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)
      [subject] = get_values(html, ".metadata-form__keywords input")

      assert subject == ""
    end

    test "should not add additional commas to keywords", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      form_data = %{"keywords" => Enum.join(dataset.business.keywords, ", ")}
      expected = Enum.join(dataset.business.keywords, ", ")

      assert {:ok, view, _html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_live_child(view, "metadata_form_editor")
      html = render_change(metadata_view, :validate, %{"form_data" => form_data})

      subject = get_value(html, ".metadata-form__keywords input")
      assert expected == subject
    end

    test "should trim spaces in keywords", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      form_data = %{"keywords" => "a , good ,  keyword   , is .... hard , to find"}

      assert {:ok, view, _html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_live_child(view, "metadata_form_editor")

      html = render_change(metadata_view, :validate, %{"form_data" => form_data})
      subject = get_value(html, ".metadata-form__keywords input")

      assert "a, good, keyword, is .... hard, to find" == subject
    end

    test "can handle lists of keywords", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      expected = Enum.join(dataset.business.keywords, ", ")
      form_data = %{"keywords" => expected}

      assert {:ok, view, _html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_live_child(view, "metadata_form_editor")

      html = render_change(metadata_view, :validate, %{"form_data" => form_data})
      subject = get_value(html, ".metadata-form__keywords input")

      assert expected == subject
    end

    test "displays all other fields", %{conn: conn} do
      org = TDG.create_organization(%{orgTitle: "Awesome Title", orgName: "awesome_title"})
      Brook.Event.send(@instance_name, organization_update(), __MODULE__, org)
      eventually(fn -> OrgStore.get(org.id) != {:ok, nil} end)

      smrt_dataset =
        TDG.create_dataset(%{
          business: %{
            description: "A description with no special characters",
            benefitRating: 1.0,
            riskRating: 0.5
          },
          technical: %{private: true, orgId: org.id}
        })

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)
      assert get_value(html, ".metadata-form__title input") == dataset.business.dataTitle
      assert get_text(html, ".metadata-form__description textarea") == dataset.business.description
      {selected_format, _} = get_select(html, ".metadata-form__format select")
      assert selected_format == dataset.technical.sourceFormat
      assert {"true", "Private"} == get_select(html, ".metadata-form__level-of-access")
      assert get_value(html, ".metadata-form__maintainer-name input") == dataset.business.contactName
      assert dataset.business.modifiedDate |> Date.to_string() =~ get_value(html, ".metadata-form__last-updated input")
      assert get_value(html, ".metadata-form__maintainer-email input") == dataset.business.contactEmail
      assert dataset.business.issuedDate |> Date.to_string() =~ get_value(html, ".metadata-form__release-date input")
      assert get_value(html, ".metadata-form__license input") == dataset.business.license
      assert get_value(html, ".metadata-form__update-frequency input") == dataset.business.publishFrequency
      assert get_value(html, ".metadata-form__spatial input") == dataset.business.spatial
      assert get_value(html, ".metadata-form__temporal input") == dataset.business.temporal

      assert {org.id, "Awesome Title"} == get_select(html, ".metadata-form__organization select")

      assert {"english", "English"} == get_select(html, ".metadata-form__language")
      assert get_value(html, ".metadata-form__homepage input") == dataset.business.homepage
      assert {"1.0", "High"} == get_select(html, ".metadata-form__benefit-rating")
      assert {"0.5", "Medium"} == get_select(html, ".metadata-form__risk-rating")
    end
  end

  describe "edit form data" do
    test "accessibility level must be public or private", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{technical: %{private: true}})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_live_child(view, "metadata_form_editor")

      assert get_select(html, ".metadata-form__level-of-access") == {"true", "Private"}

      form_data = %{"private" => false}

      html = render_change(metadata_view, :validate, %{"form_data" => form_data})
      assert get_select(html, ".metadata-form__level-of-access") == {"false", "Public"}
    end

    data_test "required #{field} field displays proper error message", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} =
        InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
        |> Datasets.save()

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_live_child(view, "metadata_form_editor")

      html = render_change(metadata_view, :validate, %{"form_data" => form_data})

      assert get_text(html, "##{field}-error-msg") == expected_error_message

      where([
        [:field, :form_data, :expected_error_message],
        [:dataTitle, %{"dataTitle" => ""}, "Please enter a valid dataset title."],
        [:description, %{"description" => ""}, "Please enter a valid description."],
        [:contactName, %{"contactName" => ""}, "Please enter a valid maintainer name."],
        [:contactEmail, %{"contactEmail" => ""}, "Please enter a valid maintainer email."],
        [:issuedDate, %{"issuedDate" => nil}, "Please enter a valid release date."],
        [:license, %{"license" => ""}, "Please enter a valid license."],
        [:publishFrequency, %{"publishFrequency" => ""}, "Please enter a valid update frequency."],
        [:orgId, %{"orgId" => ""}, "Please enter a valid organization."],
        [:license, %{"license" => ""}, "Please enter a valid license."],
        [:benefitRating, %{"benefitRating" => nil}, "Please enter a valid benefit."],
        [:riskRating, %{"riskRating" => nil}, "Please enter a valid risk."],
        [:topLevelSelector, %{"sourceFormat" => "text/xml", "topLevelSelector" => ""}, "Please enter a valid top level selector."]
      ])
    end

    test "required sourceFormat displays proper error message", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_live_child(view, "metadata_form_editor")

      form_data = %{"sourceFormat" => ""}

      html = render_change(metadata_view, :validate, %{"form_data" => form_data})
      assert get_text(html, "#sourceFormat-error-msg") == "Please enter a valid source format."
    end

    test "source format before publish", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert Enum.empty?(get_attributes(html, ".metadata-form__format select", "disabled"))
    end

    data_test "displays error when #{field} is unset", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_live_child(view, "metadata_form_editor")
      assert get_text(html, "##{field}-error-msg") == ""

      form_data = %{field => ""}

      html = render_change(metadata_view, :validate, %{"form_data" => form_data})

      assert get_text(html, "##{field}-error-msg") == expected_error_message

      where([
        [:field, :expected_error_message],
        ["benefitRating", "Please enter a valid benefit."],
        ["riskRating", "Please enter a valid risk."]
      ])
    end

    test "error message is cleared when form is updated", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{business: %{issuedDate: nil}})

      {:ok, dataset} =
        InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
        |> Datasets.save()

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_live_child(view, "metadata_form_editor")

      form_data = %{"issuedData" => nil}

      html = render_change(metadata_view, :validate, %{"form_data" => form_data})

      assert get_text(html, "#issuedDate-error-msg") == "Please enter a valid release date."

      updated_form_data = %{"issuedDate" => "2020-01-03"}

      html = render_change(metadata_view, :validate, %{"form_data" => updated_form_data})

      assert get_text(html, "#issuedDate-error-msg") == ""
    end

    test "displays error when topLevelSelector jpath is invalid", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} =
        InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
        |> Datasets.save()

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_live_child(view, "metadata_form_editor")

      form_data = %{"sourceFormat" => "application/json", "topLevelSelector" => "$.data[x]"}
      html = render_change(metadata_view, :validate, %{"form_data" => form_data})

      assert get_text(html, "#topLevelSelector-error-msg") == "Error: Expected an integer at `x]`"
    end

    test "topLevelSelector is read only when sourceFormat is not xml nor json", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{technical: %{sourceFormat: "text/csv"}})
      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      refute Enum.empty?(get_attributes(html, "#form_data_topLevelSelector", "readonly"))
    end

    test "dataset owner lists all the users in the system by email", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})
      {:ok, user} = User.create_or_update("64d1c660-4734-4b96-96e4-075f7ac9ae30", %{email: "hello@world.com"})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert {"hello@world.com", user.id} in get_all_select_options(html, ".metadata-form__dataset-owner")
    end
  end

  describe "can not edit" do
    test "source format for published dataset", %{conn: conn, curator_user: curator_user} do
      {:ok, dataset} = Datasets.create(curator_user)
      |> Datasets.update(%{submission_status: :published})

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      refute Enum.empty?(get_attributes(html, ".metadata-form__format select", "disabled"))
    end

    test "organization title", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})
      Brook.Event.send(@instance_name, dataset_update(), __MODULE__, smrt_dataset)
      eventually(fn -> DatasetStore.get(smrt_dataset.id) != {:ok, nil} end)

      org = TDG.create_organization(%{orgTitle: "Awesome Title", orgName: "awesome_title"})
      Brook.Event.send(@instance_name, organization_update(), __MODULE__, org)
      eventually(fn -> OrgStore.get(org.id) != {:ok, nil} end)

      assert {:ok, view, html} = live(conn, @url_path <> smrt_dataset.id)

      assert get_attributes(html, ".metadata-form__organization select", "disabled")
    end
  end

  describe "hidden so form_data has all the validated fields in it" do
    data_test "#{name} is hidden", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})
      {:ok, dataset} = Datasets.update(smrt_dataset)
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert get_attributes(html, "#form_data_#{name}", "type") == ["hidden"]

      where([
        [:name],
        ["orgName"],
        ["sourceType"]
      ])
    end
  end
end
