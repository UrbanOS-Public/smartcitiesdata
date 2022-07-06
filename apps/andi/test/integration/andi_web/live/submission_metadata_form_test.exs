defmodule AndiWeb.SubmissionMetadataFormTest do
  use ExUnit.Case
  use AndiWeb.Test.PublicAccessCase
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  use Placebo

  import Checkov

  @moduletag shared_data_connection: true

  import Phoenix.LiveViewTest

  import FlokiHelpers,
    only: [
      get_attributes: 3,
      get_value: 2,
      get_values: 2,
      get_select: 2,
      get_text: 2,
      find_elements: 2
    ]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Datasets.Dataset
  alias Andi.InputSchemas.Organizations
  alias Andi.InputSchemas.InputConverter

  @endpoint AndiWeb.Endpoint
  @url_path "/submissions/"

  describe "create new dataset" do
    setup %{public_subject: public_subject} do
      {:ok, public_user} = Andi.Schemas.User.create_or_update(public_subject, %{email: "bob@example.com", name: "Bob Example"})
      blank_dataset = %Dataset{id: UUID.uuid4(), technical: %{}, business: %{}}
      [blank_dataset: blank_dataset, public_user: public_user]
    end

    test "generate dataName from data title", %{public_conn: conn, blank_dataset: blank_dataset, public_user: public_user} do
      {:ok, andi_dataset} = Datasets.update(blank_dataset)
      {:ok, _} = Datasets.update(andi_dataset, %{owner_id: public_user.id})

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

    test "validation is only triggered for new datasets", %{public_conn: conn, public_user: public_user} do
      {:ok, dataset} =
        Datasets.create(public_user)
        |> Datasets.update(%{
          submission_status: :published,
          business: %{dataTitle: "Original Name"},
          technical: %{dataName: "original_name"}
        })

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_live_child(view, "metadata_form_editor")

      form_data = %{"dataTitle" => "simpledatatitle", "dataName" => dataset.technical.dataName}

      render_change(metadata_view, "validate", %{"form_data" => form_data, "_target" => ["form_data", "dataTitle"]})

      html = render(metadata_view)

      value = get_value(html, "#form_data_dataName")

      assert value == "original_name"
    end

    data_test "data title #{title} generates data name #{data_name}", %{
      public_conn: conn,
      public_user: public_user,
      blank_dataset: blank_dataset
    } do
      {:ok, andi_dataset} = Datasets.update(blank_dataset)
      {:ok, dataset} = Datasets.update(andi_dataset, %{owner_id: public_user.id})

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
  end

  describe "enter form data" do
    setup %{public_subject: public_subject} do
      {:ok, public_user} = Andi.Schemas.User.create_or_update(public_subject, %{email: "bob@example.com", name: "Bob"})
      [public_user: public_user]
    end

    test "the default language is set to english", %{public_conn: conn, public_user: public_user} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)
      {:ok, dataset} = Datasets.update(dataset, %{owner_id: public_user.id})

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)

      assert {"english", "English"} = get_select(html, ".metadata-form__language")
    end

    test "the language is set to spanish", %{public_conn: conn, public_user: public_user} do
      smrt_dataset = TDG.create_dataset(%{business: %{language: "spanish"}})

      {:ok, dataset} = Datasets.update(smrt_dataset)
      {:ok, dataset} = Datasets.update(dataset, %{owner_id: public_user.id})

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert {"spanish", "Spanish"} = get_select(html, ".metadata-form__language")
    end

    test "the language is changed from english to spanish", %{public_conn: conn, public_user: public_user} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)
      {:ok, dataset} = Datasets.update(dataset, %{owner_id: public_user.id})

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_live_child(view, "metadata_form_editor")

      form_data = %{"language" => "spanish"}

      html = render_change(metadata_view, :validate, %{"form_data" => form_data})

      assert {"spanish", "Spanish"} = get_select(html, ".metadata-form__language")
    end

    test "adds commas between keywords", %{public_conn: conn, public_user: public_user} do
      smrt_dataset = TDG.create_dataset(%{business: %{keywords: ["one", "two", "three"]}})

      {:ok, dataset} = Datasets.update(smrt_dataset)
      {:ok, dataset} = Datasets.update(dataset, %{owner_id: public_user.id})

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)
      [subject] = get_values(html, ".metadata-form__keywords input")

      assert subject =~ "one, two, three"
    end

    test "keywords input should show empty string if keywords is nil", %{public_conn: conn, public_user: public_user} do
      smrt_dataset = TDG.create_dataset(%{business: %{keywords: nil}})

      {:ok, dataset} = Datasets.update(smrt_dataset)
      {:ok, dataset} = Datasets.update(dataset, %{owner_id: public_user.id})

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)
      [subject] = get_values(html, ".metadata-form__keywords input")

      assert subject == ""
    end

    test "should not add additional commas to keywords", %{public_conn: conn, public_user: public_user} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)
      {:ok, dataset} = Datasets.update(dataset, %{owner_id: public_user.id})

      form_data = %{"keywords" => Enum.join(dataset.business.keywords, ", ")}
      expected = Enum.join(dataset.business.keywords, ", ")

      assert {:ok, view, _html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_live_child(view, "metadata_form_editor")
      html = render_change(metadata_view, :validate, %{"form_data" => form_data})

      subject = get_value(html, ".metadata-form__keywords input")
      assert expected == subject
    end

    test "should trim spaces in keywords", %{public_conn: conn, public_user: public_user} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)
      {:ok, dataset} = Datasets.update(dataset, %{owner_id: public_user.id})

      form_data = %{"keywords" => "a , good ,  keyword   , is .... hard , to find"}

      assert {:ok, view, _html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_live_child(view, "metadata_form_editor")

      html = render_change(metadata_view, :validate, %{"form_data" => form_data})
      subject = get_value(html, ".metadata-form__keywords input")

      assert "a, good, keyword, is .... hard, to find" == subject
    end

    test "can handle lists of keywords", %{public_conn: conn, public_user: public_user} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)
      {:ok, dataset} = Datasets.update(dataset, %{owner_id: public_user.id})

      expected = Enum.join(dataset.business.keywords, ", ")
      form_data = %{"keywords" => expected}

      assert {:ok, view, _html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_live_child(view, "metadata_form_editor")

      html = render_change(metadata_view, :validate, %{"form_data" => form_data})
      subject = get_value(html, ".metadata-form__keywords input")

      assert expected == subject
    end

    test "displays all other fields", %{public_conn: conn, public_user: public_user} do
      {:ok, org} =
        Organizations.create()
        |> Organizations.update(%{
          orgTitle: "Awesome Title",
          orgName: "awesome_title"
        })

      {:ok, dataset} =
        Datasets.create(public_user)
        |> Datasets.update(%{
          business: %{
            description: "A description with no special characters",
            benefitRating: 1.0,
            riskRating: 0.5
          },
          technical: %{
            private: true,
            orgId: org.id,
            sourceType: "ingest"
          }
        })

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)

      assert get_value(html, ".metadata-form__title input") == dataset.business.dataTitle
      assert get_text(html, ".metadata-form__description textarea") == dataset.business.description
      assert get_value(html, ".metadata-form__spatial input") == dataset.business.spatial
      assert get_value(html, ".metadata-form__temporal input") == dataset.business.temporal
      assert {"english", "English"} == get_select(html, ".metadata-form__language")
      assert get_value(html, ".metadata-form__homepage input") == dataset.business.homepage
    end
  end

  describe "edit form data" do
    setup %{public_subject: public_subject} do
      {:ok, public_user} = Andi.Schemas.User.create_or_update(public_subject, %{email: "bob@example.com", name: "Bob"})
      [public_user: public_user]
    end

    data_test "required #{field} field displays proper error message", %{public_conn: conn, public_user: public_user} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} =
        InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
        |> Datasets.save()

      {:ok, dataset} = Datasets.update(dataset, %{owner_id: public_user.id})

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_live_child(view, "metadata_form_editor")

      html = render_change(metadata_view, :validate, %{"form_data" => form_data})

      assert get_text(html, "##{field}-error-msg") == expected_error_message

      where([
        [:field, :form_data, :expected_error_message],
        [:dataTitle, %{"dataTitle" => ""}, "Please enter a valid dataset title."],
        [
          :description,
          %{"description" => ""},
          "Please describe your dataset. What information does it contain? Where, when, and how was the data collected? Which organization produced the dataset, if applicable?"
        ]
      ])
    end

    test "non-submission required field updateFrequency does not trigger a validation error", %{public_conn: conn, public_user: public_user} do
      smrt_dataset =
        TDG.create_dataset(%{
          business: %{
            dataTitle: "dater",
            publishFrequency: "",
            language: "English",
            contactEmail: public_user.email,
            contactName: public_user.subject_id
          }
        })

      {:ok, dataset} = Datasets.update(smrt_dataset)
      {:ok, dataset} = Datasets.update(dataset, %{owner_id: public_user.id})

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_live_child(view, "metadata_form_editor")

      render_change(metadata_view, :validate, %{
        "form_data" => %{
          "description" => "change",
          "dataTitle" => smrt_dataset.business.dataTitle,
          "contactName" => "Frank Bobbert",
          "sourceFormat" => "text/csv"
        }
      })

      html = render_change(metadata_view, :save)
      refute Enum.empty?(find_elements(html, ".component-number-status--valid"))
    end

    test "source format before publish", %{public_conn: conn, public_user: public_user} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)
      {:ok, dataset} = Datasets.update(dataset, %{owner_id: public_user.id})

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert Enum.empty?(get_attributes(html, ".metadata-form__format select", "disabled"))
    end

    test "error message is cleared when form is updated", %{public_conn: conn, public_user: public_user} do
      smrt_dataset = TDG.create_dataset(%{business: %{description: nil}})

      {:ok, dataset} =
        InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
        |> Datasets.save()

      {:ok, dataset} = Datasets.update(dataset, %{owner_id: public_user.id})

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_live_child(view, "metadata_form_editor")

      form_data = %{"description" => nil}

      html = render_change(metadata_view, :validate, %{"form_data" => form_data})

      assert get_text(html, "#description-error-msg") ==
               "Please describe your dataset. What information does it contain? Where, when, and how was the data collected? Which organization produced the dataset, if applicable?"

      updated_form_data = %{"description" => "Describe this!"}

      html = render_change(metadata_view, :validate, %{"form_data" => updated_form_data})

      assert get_text(html, "#description-error-msg") == ""
    end
  end

  describe "can not edit" do
    setup %{public_subject: public_subject} do
      {:ok, public_user} = Andi.Schemas.User.create_or_update(public_subject, %{email: "bob@example.com", name: "Bob"})
      [public_user: public_user]
    end

    test "source format for published dataset", %{public_conn: conn, public_user: public_user} do
      dataset = Datasets.create(public_user)

      Datasets.update_submission_status(dataset.id, :published)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      refute Enum.empty?(get_attributes(html, ".metadata-form__format select", "disabled"))
    end
  end
end
