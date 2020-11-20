defmodule AndiWeb.EditLiveViewTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  use Placebo
  import Checkov

  alias Andi.Services.DatasetStore

  @moduletag shared_data_connection: true

  import Phoenix.LiveViewTest
  import SmartCity.TestHelper, only: [eventually: 1, eventually: 3]

  import FlokiHelpers, only: [get_attributes: 3, get_text: 2, find_elements: 2]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.InputConverter

  @endpoint AndiWeb.Endpoint
  @url_path "/datasets/"

  setup %{curator_subject: curator_subject, public_subject: public_subject} do
    {:ok, curator} = Andi.Schemas.User.create_or_update(curator_subject, %{email: "bob@example.com"})
    {:ok, public_user} = Andi.Schemas.User.create_or_update(public_subject, %{email: "bob@example.com"})
    [curator: curator, public_user: public_user]
  end

  describe "public access to edit datasets" do
    test "public user can access their own dataset", %{public_conn: conn, public_user: public_user} do
      dataset = Datasets.create(public_user)
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
    end

    test "public user cannot access an unowned dataset", %{public_conn: conn} do
      {:ok, dataset} = TDG.create_dataset(%{}) |> Datasets.update()

      get(conn, @url_path <> dataset.id)
      |> response(404)
    end

    test "public user cannot access a dataset owned by another user", %{public_conn: conn, curator: curator} do
      dataset = Datasets.create(curator)

      get(conn, @url_path <> dataset.id)
      |> response(404)
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
      finalize_view = find_child(view, "finalize_form_editor")
      url_view = find_child(view, "url_form_editor")

      form_data = %{"cadence" => "once"}

      render_change(finalize_view, :validate, %{"form_data" => form_data})
      render_change(url_view, :save)

      eventually(fn ->
        dataset = Datasets.get(dataset.id)

        assert "once" == dataset.technical.cadence
      end)
    end

    test "publish button saves all sections", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})
      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      finalize_view = find_child(view, "finalize_form_editor")
      metadata_view = find_child(view, "metadata_form_editor")

      finalize_form_data = %{"cadence" => "once"}
      metadata_form_data = %{"description" => "cambapo"}

      render_change(finalize_view, :validate, %{"form_data" => finalize_form_data})
      render_change(metadata_view, :validate, %{"form_data" => metadata_form_data})

      render_change(finalize_view, :publish)

      eventually(fn ->
        dataset = Datasets.get(dataset.id)

        assert "once" == dataset.technical.cadence
        assert "cambapo" == dataset.business.description
      end)
    end

    test "valid form data is saved on publish", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      finalize_view = find_child(view, "finalize_form_editor")

      form_data = %{"cadence" => "once"}

      render_change(finalize_view, :validate, %{"form_data" => form_data})
      render_change(finalize_view, :publish)

      eventually(
        fn ->
          dataset = Datasets.get(dataset.id)
          {:ok, saved_dataset} = InputConverter.andi_dataset_to_smrt_dataset(dataset)

          assert {:ok, ^saved_dataset} = DatasetStore.get(dataset.id)
        end,
        10,
        1_000
      )
    end

    test "valid dataset's submission status is updated on publish", %{conn: conn} do
      allow(AndiWeb.Endpoint.broadcast(any(), any(), any()), return: :ok, meck_options: [:passthrough])
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)
      Datasets.update_submission_status(dataset.id, :approved)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      finalize_view = find_child(view, "finalize_form_editor")

      form_data = %{"cadence" => "once"}

      render_change(finalize_view, :validate, %{"form_data" => form_data})
      render_change(finalize_view, :publish)

      eventually(
        fn ->
          assert %{submission_status: :published} = Datasets.get(dataset.id)
        end,
        10,
        1_000
      )
    end

    test "invalid dataset's submission status is not updated on publish", %{conn: conn} do
      allow(AndiWeb.Endpoint.broadcast(any(), any(), any()), return: :ok, meck_options: [:passthrough])
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)
      submission_status = :approved
      Datasets.update_submission_status(dataset.id, submission_status)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_child(view, "metadata_form_editor")
      finalize_view = find_child(view, "finalize_form_editor")

      form_data = %{"publishFrequency" => nil}

      render_change(metadata_view, :validate, %{"form_data" => form_data})
      render_change(finalize_view, :publish)

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
      metadata_view = find_child(view, "metadata_form_editor")
      finalize_view = find_child(view, "finalize_form_editor")

      form_data = %{"publishFrequency" => nil}

      render_change(metadata_view, :validate, %{"form_data" => form_data})
      render_change(finalize_view, :publish)

      Process.sleep(2_000)
      assert nil == Datasets.get(dataset.id) |> get_in([:business, :publishFrequency])
    end

    test "success message is displayed when form data is saved", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} =
        InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
        |> Datasets.save()

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      finalize_view = find_child(view, "finalize_form_editor")

      assert get_text(html, "#snackbar") == ""

      render_change(finalize_view, :save, %{})
      html = render(view)

      refute Enum.empty?(find_elements(html, "#snackbar.success-message"))
      assert get_text(html, "#snackbar") != ""
    end

    test "saving form as draft does not send brook event", %{conn: conn} do
      allow(AndiWeb.Endpoint.broadcast_from(any(), any(), any(), any()), return: :ok, meck_options: [:passthrough])
      allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)
      smrt_dataset = TDG.create_dataset(%{business: %{issuedDate: nil}})

      {:ok, dataset} =
        InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
        |> Datasets.save()

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      url_view = find_child(view, "url_form_editor")

      render_change(url_view, :save, %{})

      refute_called Brook.Event.send(any(), any(), any(), any())
    end

    test "saving form as draft with invalid changes warns user", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{business: %{dataTitle: ""}})

      {:ok, dataset} =
        InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
        |> Datasets.save()

      assert {:ok, view, _} = live(conn, @url_path <> dataset.id)
      metadata_view = find_child(view, "metadata_form_editor")

      form_data = %{"dataTitle" => ""}

      render_change(metadata_view, :validate, %{"form_data" => form_data})
      render_change(metadata_view, :save, %{})
      html = render(view)

      assert get_text(html, "#snackbar") == "Saved successfully. You may need to fix errors before publishing."
    end

    test "allows clearing modified date", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{business: %{modifiedDate: "2020-01-01T00:00:00Z"}})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_child(view, "metadata_form_editor")
      finalize_view = find_child(view, "finalize_form_editor")

      form_data = %{
        "modifiedDate" => "",
        "dataName" => "somethimn",
        "orgName" => "something",
        "private" => false,
        "sourceFormat" => "something",
        "sourceType" => "something",
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
      render_change(finalize_view, :publish)

      eventually(
        fn ->
          assert {:ok, nil} != DatasetStore.get(dataset.id)
        end,
        30,
        1_000
      )
    end

    test "does not save when dataset org and data name match existing dataset", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})
      {:ok, dataset} = Datasets.update(smrt_dataset)
      {:ok, other_dataset} = Datasets.update(TDG.create_dataset(%{}))

      form_data = %{"dataTitle" => other_dataset.technical.dataName, "orgName" => other_dataset.technical.orgName}

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_child(view, "metadata_form_editor")
      finalize_view = find_child(view, "finalize_form_editor")

      render_change(metadata_view, :validate, %{"form_data" => form_data, "_target" => ["form_data", "dataTitle"]})
      render_change(metadata_view, :validate_system_name, %{})
      render_change(finalize_view, :publish)

      assert render(view) |> get_text("#snackbar") =~ "errors"
    end

    data_test "allows saving with empty #{field}", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{technical: %{field => %{"x" => "y"}}})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      form_data = %{"sourceUrl" => "cam.com", field => %{"x" => "y"}}

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      url_view = find_child(view, "url_form_editor")
      finalize_view = find_child(view, "finalize_form_editor")

      render_change(url_view, :validate, %{"form_data" => form_data})
      render_change(finalize_view, :publish)

      eventually(
        fn ->
          dataset = Datasets.get(dataset.id)
          {:ok, saved_dataset} = InputConverter.andi_dataset_to_smrt_dataset(dataset)
          assert {:ok, ^saved_dataset} = DatasetStore.get(dataset.id)
        end,
        20,
        500
      )

      where(field: ["sourceQueryParams", "sourceHeaders"])
    end

    test "alert shows when section changes are unsaved on cancel action", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})
      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      metadata_view = find_child(view, "metadata_form_editor")

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
      metadata_view = find_child(view, "metadata_form_editor")

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
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      finalize_view = find_child(view, "finalize_form_editor")

      form_data = %{"cadence" => "once"}

      render_change(finalize_view, :validate, %{"form_data" => form_data})
      render_change(finalize_view, :publish)
      html = render(view)

      refute Enum.empty?(find_elements(html, ".publish-success-modal--visible"))
    end

    test "continuing to edit after publish reloads the page", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      assert Enum.empty?(get_attributes(html, "#form_data_sourceFormat", "disabled"))

      finalize_view = find_child(view, "finalize_form_editor")
      form_data = %{"cadence" => "once"}

      render_change(finalize_view, :validate, %{"form_data" => form_data})
      render_change(finalize_view, :publish)
      html = render(view)

      eventually(fn ->
        assert !Enum.empty?(find_elements(html, ".publish-success-modal--visible"))
      end)

      render_change(view, "reload-page", %{})
      url = @url_path <> dataset.id

      assert_redirect(view, url)
    end

    test "allows publish of invalid url form with valid extract step form", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{technical: %{extractSteps: [%{type: "http", context: %{}}]}})

      {:ok, dataset} = Datasets.update(smrt_dataset)
      extract_step_id = get_extract_step_id(dataset, 0)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      finalize_view = find_child(view, "finalize_form_editor")
      url_view = find_child(view, "url_form_editor")
      extract_step_view = find_child(view, "extract_step_form_editor")

      url_form_data = %{"sourceUrl" => ""}
      extract_form_data = %{"type" => "http", "action" => "GET", "url" => "cam.com"}

      render_change(url_view, :validate, %{"form_data" => url_form_data})
      render_change([extract_step_view, "#step-#{extract_step_id}"], :validate, %{"form_data" => extract_form_data})

      render_change(finalize_view, :publish)
      html = render(view)

      refute Enum.empty?(find_elements(html, ".publish-success-modal--visible"))

      eventually(fn ->
        {:ok, dataset_sent} = DatasetStore.get(smrt_dataset.id)
        assert dataset_sent != nil
        assert dataset_sent.technical.sourceUrl == smrt_dataset.business.homepage
      end)
    end

    test "allows publish of invalid extract form with valid url form", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{technical: %{extractSteps: [%{type: "http", context: %{}}]}})

      {:ok, dataset} = Datasets.update(smrt_dataset)
      extract_step_id = get_extract_step_id(dataset, 0)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      finalize_view = find_child(view, "finalize_form_editor")
      url_view = find_child(view, "url_form_editor")
      extract_step_view = find_child(view, "extract_step_form_editor")

      url_form_data = %{"sourceUrl" => "cam.com"}
      extract_form_data = %{"type" => "http", "action" => "GET", "url" => ""}

      render_change(url_view, :validate, %{"form_data" => url_form_data})
      render_change([extract_step_view, "#step-#{extract_step_id}"], :validate, %{"form_data" => extract_form_data})

      render_change(finalize_view, :publish)
      html = render(view)

      refute Enum.empty?(find_elements(html, ".publish-success-modal--visible"))

      eventually(fn ->
        {:ok, dataset_sent} = DatasetStore.get(smrt_dataset.id)
        assert dataset_sent != nil
        assert dataset_sent.technical.extractSteps == []
      end)
    end

    test "replaces url form elements when both url form and extract form are valid", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{technical: %{extractSteps: [%{type: "http", context: %{}}]}})

      {:ok, dataset} = Datasets.update(smrt_dataset)
      extract_step_id = get_extract_step_id(dataset, 0)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      finalize_view = find_child(view, "finalize_form_editor")
      url_view = find_child(view, "url_form_editor")
      extract_step_view = find_child(view, "extract_step_form_editor")

      url_form_data = %{"sourceUrl" => "cam.com"}
      extract_form_data = %{"action" => "POST", "url" => "cam.com", "body" => "[]"}

      render_change(url_view, :validate, %{"form_data" => url_form_data})
      render_change([extract_step_view, "#step-#{extract_step_id}"], :validate, %{"form_data" => extract_form_data})

      render_change(finalize_view, :publish)
      html = render(view)

      refute Enum.empty?(find_elements(html, ".publish-success-modal--visible"))

      eventually(fn ->
        {:ok, dataset_sent} = DatasetStore.get(smrt_dataset.id)
        assert dataset_sent != nil
        assert dataset_sent.technical.extractSteps != []
        assert dataset_sent.technical.sourceUrl == smrt_dataset.business.homepage
        assert dataset_sent.technical.extractSteps |> List.first() |> get_in(["context", "body"]) == []
      end)
    end

    test "fails to publish if invalid extract steps are found", %{conn: conn} do
      extract_steps = [
        %{type: "http", context: %{action: "GET", url: ""}},
        %{type: "http", context: %{action: "GET", url: "example2.com"}}
      ]

      smrt_dataset = TDG.create_dataset(%{technical: %{extractSteps: extract_steps, sourceUrl: ""}})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      finalize_view = find_child(view, "finalize_form_editor")

      render_change(finalize_view, :publish)
      html = render(view)
      assert Enum.empty?(find_elements(html, ".publish-success-modal--visible"))

      assert {:ok, nil} == DatasetStore.get(smrt_dataset.id)
    end

    test "published extract steps have assigns and variables", %{conn: conn} do
      extract_steps = [
        %{type: "http", context: %{action: "GET", url: "example2.com"}}
      ]

      smrt_dataset = TDG.create_dataset(%{technical: %{extractSteps: extract_steps}})

      {:ok, dataset} = Datasets.update(smrt_dataset)
      extract_step_id = get_extract_step_id(dataset, 0)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      finalize_view = find_child(view, "finalize_form_editor")
      extract_step_view = find_child(view, "extract_step_form_editor")

      extract_form_data = %{"type" => "http", "action" => "GET", "url" => "example.com/{{variable_name}}"}

      render_change([extract_step_view, "#step-#{extract_step_id}"], :validate, %{"form_data" => extract_form_data})

      render_change(finalize_view, :publish)
      html = render(view)

      refute Enum.empty?(find_elements(html, ".publish-success-modal--visible"))

      eventually(
        fn ->
          {:ok, dataset_sent} = DatasetStore.get(smrt_dataset.id)
          assert dataset_sent != nil

          dataset_http_extract_step = get_in(dataset_sent, [:technical, :extractSteps]) |> hd()
          assert dataset_http_extract_step["context"]["url"] == "example.com/{{variable_name}}"
          assert dataset_http_extract_step["assigns"] != nil
        end,
        500,
        50
      )
    end

    data_test "does not publish when extract steps are invalid", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{technical: %{extractSteps: extract_steps}})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      extract_steps_form_view = find_child(view, "extract_step_form_editor")
      finalize_view = find_child(view, "finalize_form_editor")

      render_change(finalize_view, :publish)
      html = render(view)

      assert Enum.empty?(find_elements(html, ".publish-success-modal--visible"))
      refute Enum.empty?(find_elements(html, "#extract-step-form .component-header .section-number .component-number-status--invalid"))

      where([
        extract_steps: [[], nil, [%{type: "date", context: %{destination: "blah", format: "{YYYY}"}}]]
      ])
    end
  end

  describe "delete dataset" do
    test "dataset is deleted after confirmation", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      render_change(view, "confirm-delete", %{"id" => dataset.id})

      eventually(fn ->
        assert nil == Datasets.get(dataset.id)
      end)
    end
  end

  defp get_extract_step_id(dataset, index) do
    dataset
    |> Andi.InputSchemas.StructTools.to_map()
    |> get_in([:technical, :extractSteps])
    |> Enum.at(index)
    |> Map.get(:id)
  end
end
