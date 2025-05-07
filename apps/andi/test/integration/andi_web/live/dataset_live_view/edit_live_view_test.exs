defmodule AndiWeb.EditLiveViewTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase

  import Checkov
  import Mock

  alias Andi.Services.DatasetStore

  @moduletag shared_data_connection: true

  import Phoenix.LiveViewTest
  import SmartCity.Event
  import SmartCity.TestHelper, only: [eventually: 1, eventually: 3]
  import FlokiHelpers

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.InputConverter
  alias Andi.Schemas.AuditEvent
  alias Andi.Schemas.AuditEvents

  @endpoint AndiWeb.Endpoint
  @url_path "/datasets/"

  setup %{curator_subject: curator_subject, public_subject: public_subject} do
    {:ok, curator} = Andi.Schemas.User.create_or_update(curator_subject, %{email: "bob@example.com", name: "Bob"})
    {:ok, public_user} = Andi.Schemas.User.create_or_update(public_subject, %{email: "bob@example.com", name: "Bob"})
    [curator: curator, public_user: public_user]
  end

  describe "public access for dataset submission" do
    test "public user can access their own dataset", %{public_conn: conn, public_user: public_user} do
      dataset = Datasets.create(public_user)
      assert {:ok, view, html} = live(conn, "/submissions/" <> dataset.id)
    end

    test "public user cannot access an unowned dataset", %{public_conn: conn} do
      {:ok, dataset} = TDG.create_dataset(%{}) |> Datasets.update()

      get(conn, "/datasets/" <> dataset.id)
      |> response(302)

      get(conn, "/submissions/" <> dataset.id)
      |> response(404)
    end

    test "public user cannot access a dataset owned by another user", %{public_conn: conn, curator: curator} do
      dataset = Datasets.create(curator)

      get(conn, "/datasets/" <> dataset.id)
      |> response(302)

      get(conn, "/submissions/" <> dataset.id)
      |> response(404)
    end

    test "public user cannot access edit view, even for a dataset they own", %{public_conn: conn, public_user: public_user} do
      dataset = Datasets.create(public_user)

      assert get(conn, "/datasets/" <> dataset.id)
             |> response(302)
    end
  end

  describe "curator access to edit datasets" do
    test "curator can access their own dataset", %{curator_conn: conn, curator: curator} do
      dataset = Datasets.create(curator)
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
    end

    test "curator can access an unowned dataset", %{curator_conn: conn} do
      {:ok, dataset} = TDG.create_dataset(%{}) |> Datasets.update()
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
    end

    test "curator can access a dataset owned by another user", %{curator_conn: conn, public_user: public_user} do
      dataset = Datasets.create(public_user)
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
    end
  end

  describe "save and publish form data" do
    test "save button in one section saves all sections", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{technical: %{cadence: "never"}})
      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_live_child(view, "metadata_form_editor")
      form_data = %{"dataTitle" => "new title"}

      render_change(metadata_view, :validate, %{"form_data" => form_data})
      render_change(view, :save)

      eventually(fn ->
        dataset = Datasets.get(dataset.id)

        assert "new title" == dataset.business.dataTitle
      end)
    end

    test "publish button saves all sections", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})
      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_live_child(view, "metadata_form_editor")
      metadata_form_data = %{"description" => "cambapo"}

      render_change(metadata_view, :validate, %{"form_data" => metadata_form_data})

      render_change(view, :publish)

      eventually(fn ->
        dataset = Datasets.get(dataset.id)
        assert "cambapo" == dataset.business.description
      end)
    end

    test "valid form data is saved on publish", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{technical: %{sourceType: "remote"}})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      data_dict_view = find_live_child(view, "data_dictionary_form_editor")
      changed_schema_name = "testing"

      new_schema = %{
        "0" => %{
          "biased" => "",
          "bread_crumb" => "test",
          "dataset_id" => dataset.id,
          "demographic" => "",
          "description" => "",
          "id" => UUID.uuid4(),
          "ingestion_id" => "",
          "masked" => "",
          "name" => changed_schema_name,
          "pii" => "",
          "rationale" => "",
          "type" => "string"
        }
      }

      form_data = %{"data_dictionary_form_schema" => %{"schema" => new_schema}}
      render_change(data_dict_view, :validate, form_data)
      render_change(view, :publish)

      eventually(
        fn ->
          dataset = Datasets.get(dataset.id)
          {:ok, saved_dataset} = InputConverter.andi_dataset_to_smrt_dataset(dataset)
          assert hd(saved_dataset.technical.schema).name == changed_schema_name

          assert {:ok, ^saved_dataset} = DatasetStore.get(dataset.id)
          assert Andi.Schemas.AuditEvents.get_all_by_event_id(dataset.id) != []
        end,
        10,
        1_000
      )
    end

    test "valid dataset's submission status is updated on publish", %{conn: conn} do
      with_mock(AndiWeb.Endpoint, [:passthrough], broadcast: fn _, _, _ -> :ok end) do
        smrt_dataset = TDG.create_dataset(%{technical: %{sourceType: "remote"}})

        {:ok, dataset} = Datasets.update(smrt_dataset)
        Datasets.update_submission_status(dataset.id, :approved)

        assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
        metadata_view = find_live_child(view, "metadata_form_editor")
        form_data = %{"dataTitle" => "new data"}

        render_change(metadata_view, :validate, %{"form_data" => form_data})
        render_change(view, :publish)

        eventually(
          fn ->
            assert %{submission_status: :published} = Datasets.get(dataset.id)
            assert [%AuditEvent{event: smrt_dataset}] = AuditEvents.get_all_of_type(dataset_update())
          end,
          10,
          1_000
        )
      end
    end

    test "invalid dataset's submission status is not updated on publish", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)
      submission_status = :approved
      Datasets.update_submission_status(dataset.id, submission_status)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_live_child(view, "metadata_form_editor")

      form_data = %{"publishFrequency" => nil}

      render_change(metadata_view, :validate, %{"form_data" => form_data})
      render_change(view, :publish)

      eventually(
        fn ->
          assert %{submission_status: ^submission_status} = Datasets.get(dataset.id)
        end,
        10,
        1_000
      )
    end

    test "invalid form data is saved on publish", %{conn: conn} do
      smrt_dataset =
        TDG.create_dataset(%{
          business: %{publishFrequency: "I dunno, whenever, I guess"}
        })

      {:ok, dataset} = Datasets.update(smrt_dataset)
      assert "I dunno, whenever, I guess" == Datasets.get(dataset.id) |> get_in([:business, :publishFrequency])

      assert {:ok, view, _html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_live_child(view, "metadata_form_editor")

      form_data = %{"publishFrequency" => nil}

      render_change(metadata_view, :validate, %{"form_data" => form_data})
      render_change(view, :publish)

      Process.sleep(2_000)
      assert nil == Datasets.get(dataset.id) |> get_in([:business, :publishFrequency])
    end

    test "success message is displayed when form data is saved", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} =
        InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
        |> Datasets.save()

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert get_text(html, "#snackbar") == ""

      render_change(view, :save, %{})
      html = render(view)

      refute Enum.empty?(find_elements(html, "#snackbar.success-message"))
      assert get_text(html, "#snackbar") != ""
    end

    test "saving form as draft does not send brook event", %{conn: conn} do
      with_mocks([
        {AndiWeb.Endpoint, [:passthrough], [broadcast_from: fn _, _, _, _ -> :ok end]},
        {Brook.Event, [], [send: fn _, _, _, _ -> :ok end]}
      ]) do
        smrt_dataset = TDG.create_dataset(%{business: %{issuedDate: nil}})

        {:ok, dataset} =
          InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
          |> Datasets.save()

        assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

        render_change(view, :save, %{})

        assert_not_called(Brook.Event.send(:_, :_, :_, :_))
      end
    end

    test "saving form as draft with invalid changes warns user", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{business: %{dataTitle: ""}})

      {:ok, dataset} =
        InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
        |> Datasets.save()

      assert {:ok, view, _} = live(conn, @url_path <> dataset.id)
      metadata_view = find_live_child(view, "metadata_form_editor")

      form_data = %{"dataTitle" => ""}

      render_change(metadata_view, :validate, %{"form_data" => form_data})
      render_change(view, :save, %{})
      html = render(view)

      assert get_text(html, "#snackbar") == "Saved successfully. You may need to fix errors before publishing."
    end

    test "allows clearing modified date", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{business: %{modifiedDate: "2020-01-01T00:00:00Z"}})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_live_child(view, "metadata_form_editor")

      form_data = %{
        "modifiedDate" => "",
        "dataName" => "somethimn",
        "orgName" => "something",
        "private" => false,
        "sourceType" => "remote",
        "benefitRating" => 1.0,
        "contactEmail" => "something@something.com",
        "contactName" => "something",
        "dataTitle" => "something",
        "description" => "something",
        "issuedDate" => ~D[1899-10-20],
        "license" => "https://www.test.net",
        "orgTitle" => "something",
        "publishFrequency" => "something",
        "riskRating" => 1.0
      }

      render_change(metadata_view, :validate, %{"form_data" => form_data})
      render_change(view, :publish)

      eventually(
        fn ->
          assert {:ok, nil} != DatasetStore.get(dataset.id)
        end,
        100,
        50
      )
    end

    test "does not save when dataset org and data name match existing dataset", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})
      {:ok, dataset} = Datasets.update(smrt_dataset)
      {:ok, other_dataset} = Datasets.update(TDG.create_dataset(%{}))

      form_data = %{"dataTitle" => other_dataset.technical.dataName, "orgName" => other_dataset.technical.orgName}

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_live_child(view, "metadata_form_editor")

      render_change(metadata_view, :validate, %{"form_data" => form_data, "_target" => ["form_data", "dataTitle"]})
      render_change(metadata_view, :validate_system_name, %{})
      render_change(view, :publish)

      assert render(view) |> get_text("#snackbar") =~ "errors"
    end

    test "alert shows when section changes are unsaved on cancel action", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})
      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_live_child(view, "metadata_form_editor")

      form_data = %{"dataTitle" => "new dataset title"}

      render_change(metadata_view, "validate", %{"form_data" => form_data})

      refute Enum.empty?(find_elements(html, ".unsaved-changes-modal--hidden"))

      render_change(metadata_view, "cancel-edit", %{})
      html = render(view)

      refute Enum.empty?(find_elements(html, ".unsaved-changes-modal--visible"))
    end

    test "clicking cancel takes you back to the datasets page without saved changes", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})
      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_live_child(view, "metadata_form_editor")

      form_data = %{"dataTitle" => "new dataset title"}

      render_change(metadata_view, "validate", %{"form_data" => form_data})
      render_change(metadata_view, "cancel-edit", %{})
      html = render(view)

      refute Enum.empty?(find_elements(html, ".unsaved-changes-modal--visible"))

      render_change(view, "force-cancel-edit", %{})

      assert "new dataset title" != Datasets.get(dataset.id) |> get_in([:business, :dataTitle])

      assert_redirect(view, "/datasets")
    end

    test "successfully publishing presents modal", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{technical: %{sourceType: "remote"}})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      render_change(view, :publish)
      html = render(view)

      refute Enum.empty?(find_elements(html, ".publish-success-modal--visible"))
    end

    test "continuing to edit after publish reloads the page", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{technical: %{sourceType: "remote"}})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      render_change(view, :publish)
      html = render(view)

      eventually(fn ->
        assert not Enum.empty?(find_elements(html, ".publish-success-modal--visible"))
      end)

      render_change(view, "reload-page", %{})
      url = @url_path <> dataset.id

      assert_redirect(view, url)
    end
  end

  describe "delete dataset" do
    test "dataset is deleted after confirmation", %{conn: conn} do
      dataset = TDG.create_dataset(%{})
      Brook.Event.send(:andi, dataset_update(), :test, dataset)

      eventually(fn ->
        assert nil != Datasets.get(dataset.id)
      end)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      render_change(view, "delete-confirmed", %{"id" => dataset.id})

      eventually(fn ->
        assert nil == Datasets.get(dataset.id)
        assert [%AuditEvent{event: dataset}] = AuditEvents.get_all_of_type(dataset_delete())
      end)
    end
  end

  describe "review dataset" do
    setup do
      smrt_dataset =
        TDG.create_dataset(%{
          technical: %{
            extractSteps: [
              %{
                type: "http",
                context: %{
                  action: "GET",
                  url: "example.com"
                }
              }
            ]
          }
        })

      {:ok, _} = Datasets.update(smrt_dataset)
      {:ok, andi_dataset} = Datasets.update_submission_status(smrt_dataset.id, :submitted)

      [andi_dataset: andi_dataset]
    end

    data_test "marks dataset status as #{status} when corresponding button is clicked", %{conn: conn, andi_dataset: andi_dataset} do
      {:ok, andi_dataset} = Datasets.update_submission_status(andi_dataset.id, :submitted)
      assert {:ok, view, _} = live(conn, @url_path <> andi_dataset.id)

      view
      |> element(button_selector)
      |> render_click()

      eventually(fn ->
        assert Datasets.get(andi_dataset.id)[:submission_status] == status
      end)

      where([
        [:button_selector, :status],
        ["#approve-button", :published],
        ["#reject-button", :rejected]
      ])
    end

    test "publishes a dataset when it is approved", %{conn: conn, andi_dataset: andi_dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> andi_dataset.id)

      html =
        view
        |> element("#approve-button")
        |> render_click()

      refute Enum.empty?(find_elements(html, ".publish-success-modal--visible"))

      eventually(fn ->
        assert DatasetStore.get(andi_dataset.id) != {:ok, nil}
      end)
    end

    test "redirects user to homepage when dataset is rejected", %{conn: conn, andi_dataset: andi_dataset} do
      assert {:ok, view, _} = live(conn, @url_path <> andi_dataset.id)

      view
      |> element("#reject-button")
      |> render_click()

      assert_redirect(view, "/datasets")
    end

    test "conditionally shows review buttons", %{conn: conn, andi_dataset: andi_dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> andi_dataset.id)
      assert Enum.empty?(find_elements(html, "#publish-button"))
      refute Enum.empty?(find_elements(html, "#reject-button"))
      refute Enum.empty?(find_elements(html, "#approve-button"))

      Datasets.update_submission_status(andi_dataset.id, :approved)

      assert {:ok, view, html} = live(conn, @url_path <> andi_dataset.id)
      refute Enum.empty?(find_elements(html, "#publish-button"))
      assert Enum.empty?(find_elements(html, "#reject-button"))
      assert Enum.empty?(find_elements(html, "#approve-button"))
    end
  end

  describe "Disable Schema After Publish" do
    setup do
      published_dataset =
        TDG.create_dataset(%{
          technical: %{
            schema: [
              %{name: "my_list", type: "list", itemType: "boolean"},
              %{name: "my_int", type: "integer"},
              %{name: "my_string", type: "string"},
              %{format: "{ISO:Extended:Z}", name: "my_date", type: "date"},
              %{name: "my_float", type: "float"},
              %{name: "my_boolean", type: "boolean"}
            ]
          }
        })
        |> Map.put(:submission_status, :published)

      date_dataset =
        TDG.create_dataset(%{
          technical: %{
            schema: [
              %{format: "{ISO:Extended:Z}", name: "my_date", type: "date"}
            ]
          }
        })
        |> Map.put(:submission_status, :published)

      list_dataset =
        TDG.create_dataset(%{
          technical: %{
            schema: [
              %{name: "my_list", type: "list", itemType: "boolean"}
            ]
          }
        })
        |> Map.put(:submission_status, :published)

      unpublished_dataset =
        TDG.create_dataset(%{
          technical: %{
            schema: [
              %{name: "my_list", type: "list", itemType: "boolean"},
              %{name: "my_int", type: "integer"},
              %{name: "my_string", type: "string"},
              %{format: "{ISO:Extended:Z}", name: "my_date", type: "date"},
              %{name: "my_float", type: "float"},
              %{name: "my_boolean", type: "boolean"}
            ]
          }
        })

      {:ok, _} = Datasets.update(unpublished_dataset)
      {:ok, _} = Datasets.update(published_dataset)
      {:ok, _} = Datasets.update(list_dataset)
      {:ok, _} = Datasets.update(date_dataset)

      [
        published_dataset: published_dataset,
        unpublished_dataset: unpublished_dataset,
        date_dataset: date_dataset,
        list_dataset: list_dataset
      ]
    end

    test "Upload section conditionally does not exist", %{
      conn: conn,
      published_dataset: published_dataset,
      unpublished_dataset: unpublished_dataset
    } do
      assert {:ok, view, html} = live(conn, @url_path <> published_dataset.id)
      assert Enum.empty?(find_elements(html, ".data-dictionary-form__file-upload"))

      assert {:ok, view, html} = live(conn, @url_path <> unpublished_dataset.id)
      refute Enum.empty?(find_elements(html, ".data-dictionary-form__file-upload"))
    end

    test "Read-Only warning conditionally does exist", %{
      conn: conn,
      published_dataset: published_dataset,
      unpublished_dataset: unpublished_dataset
    } do
      assert {:ok, view, html} = live(conn, @url_path <> published_dataset.id)
      refute Enum.empty?(find_elements(html, ".data-dictionary-disabled-warning"))

      assert {:ok, view, html} = live(conn, @url_path <> unpublished_dataset.id)
      assert Enum.empty?(find_elements(html, ".data-dictionary-disabled-warning"))
    end

    test "Add/Remove Schema Field buttons are conditionally disabled", %{
      conn: conn,
      published_dataset: published_dataset,
      unpublished_dataset: unpublished_dataset
    } do
      assert {:ok, view, html} = live(conn, @url_path <> published_dataset.id)
      refute Enum.empty?(get_attributes(html, "#add-button", "disabled"))
      refute Enum.empty?(get_attributes(html, "#remove-button", "disabled"))

      assert {:ok, view, html} = live(conn, @url_path <> unpublished_dataset.id)
      assert Enum.empty?(get_attributes(html, "#add-button", "disabled"))
      assert Enum.empty?(get_attributes(html, "#remove-button", "disabled"))
    end

    test "Editor Fields Name is conditionally disabled", %{
      conn: conn,
      published_dataset: published_dataset,
      unpublished_dataset: unpublished_dataset
    } do
      assert {:ok, view, html} = live(conn, @url_path <> published_dataset.id)
      refute Enum.empty?(get_attributes(html, ".data-dictionary-field-editor__name input", "disabled"))

      assert {:ok, view, html} = live(conn, @url_path <> unpublished_dataset.id)
      assert Enum.empty?(get_attributes(html, ".data-dictionary-field-editor__name input", "disabled"))
    end

    test "Editor Fields Type is conditionally disabled", %{
      conn: conn,
      published_dataset: published_dataset,
      unpublished_dataset: unpublished_dataset
    } do
      assert {:ok, view, html} = live(conn, @url_path <> published_dataset.id)
      refute Enum.empty?(get_attributes(html, ".data-dictionary-field-editor__type select", "disabled"))

      assert {:ok, view, html} = live(conn, @url_path <> unpublished_dataset.id)
      assert Enum.empty?(get_attributes(html, ".data-dictionary-field-editor__type select", "disabled"))
    end

    test "Editor Fields List Type is conditionally disabled", %{
      conn: conn,
      list_dataset: list_dataset,
      unpublished_dataset: unpublished_dataset
    } do
      assert {:ok, view, html} = live(conn, @url_path <> list_dataset.id)
      refute Enum.empty?(get_attributes(html, "#data_dictionary_field_editor_item_type", "disabled"))

      assert {:ok, view, html} = live(conn, @url_path <> unpublished_dataset.id)
      assert Enum.empty?(get_attributes(html, "#data_dictionary_field_editor_item_type", "disabled"))
    end

    test "Editor Fields Datetime Format is conditionally disabled", %{
      conn: conn,
      date_dataset: date_dataset,
      unpublished_dataset: unpublished_dataset
    } do
      assert {:ok, view, html} = live(conn, @url_path <> date_dataset.id)
      refute Enum.empty?(get_attributes(html, "#data_dictionary_field_editor_format", "disabled"))

      assert {:ok, view, html} = live(conn, @url_path <> unpublished_dataset.id)
      assert Enum.empty?(get_attributes(html, "#data_dictionary_field_editor_format", "disabled"))
    end

    test "Editor Fields Default Date is conditionally disabled", %{
      conn: conn,
      date_dataset: date_dataset,
      unpublished_dataset: unpublished_dataset
    } do
      assert {:ok, view, html} = live(conn, @url_path <> date_dataset.id)
      refute Enum.empty?(get_attributes(html, "#data_dictionary_field_editor__use-default", "disabled"))

      assert {:ok, view, html} = live(conn, @url_path <> unpublished_dataset.id)
      assert Enum.empty?(get_attributes(html, "#data_dictionary_field_editor__use-default", "disabled"))
    end
  end

  describe "Event Log Section" do
    setup do
      published_dataset =
        TDG.create_dataset(%{
          technical: %{
            schema: [
              %{name: "my_list", type: "list", itemType: "boolean"},
              %{name: "my_int", type: "integer"},
              %{name: "my_string", type: "string"},
              %{format: "{ISO:Extended:Z}", name: "my_date", type: "date"},
              %{name: "my_float", type: "float"},
              %{name: "my_boolean", type: "boolean"}
            ]
          }
        })
        |> Map.put(:submission_status, :published)

      {:ok, _} = Datasets.update(published_dataset)

      [published_dataset: published_dataset]
    end

    test "Event Log Section exists", %{
      conn: conn,
      published_dataset: published_dataset
    } do
      assert {:ok, view, html} = live(conn, @url_path <> published_dataset.id)
      refute Enum.empty?(find_elements(html, "#event_log"))
    end

    test "Event Log table has no rows when no events have been logged", %{
      conn: conn,
      published_dataset: published_dataset
    } do
      assert {:ok, view, html} = live(conn, @url_path <> published_dataset.id)
      assert Enum.empty?(find_elements(html, ".event_element"))
    end

    test "Event Log table has equal rows after events have been logged", %{
      conn: conn,
      published_dataset: published_dataset
    } do
      assert {:ok, view, html} = live(conn, @url_path <> published_dataset.id)
      assert Enum.empty?(find_elements(html, ".event_element"))
    end
  end
end
