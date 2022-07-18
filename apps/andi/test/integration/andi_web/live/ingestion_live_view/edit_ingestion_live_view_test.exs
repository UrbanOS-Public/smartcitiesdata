defmodule AndiWeb.EditIngestionLiveViewTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase

  @moduletag shared_data_connection: true
  @instance_name Andi.instance_name()

  import SmartCity.Event, only: [ingestion_update: 0, ingestion_delete: 0, dataset_update: 0]
  use Placebo
  import Phoenix.LiveViewTest
  import SmartCity.TestHelper, only: [eventually: 1, eventually: 3]

  import FlokiHelpers,
    only: [
      find_elements: 2,
      get_texts: 2,
      get_attributes: 3,
      get_text: 2
    ]

  alias SmartCity.TestDataGenerator, as: TDG

  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Ingestions
  alias Andi.Schemas.AuditEvents
  alias Andi.Services.IngestionStore
  alias Andi.InputSchemas.InputConverter

  @url_path "/ingestions"

  describe "ingestions" do
    setup do
      dataset = TDG.create_dataset(%{})
      ingestion_id = UUID.uuid4()
      ingestion = TDG.create_ingestion(%{id: ingestion_id, targetDataset: dataset.id})

      Brook.Event.send(@instance_name, dataset_update(), :andi, dataset)
      Brook.Event.send(@instance_name, ingestion_update(), :andi, ingestion)

      eventually(fn ->
        assert Ingestions.get(ingestion.id) != nil
      end)

      %{ingestion: ingestion}
    end

    test "clicking cancel takes you back to the ingestions page when there are no unsaved changes", %{
      curator_conn: conn,
      ingestion: ingestion
    } do
      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")

      cancel_button = element(view, ".btn--cancel", "Discard Changes")
      render_click(cancel_button)

      assert_redirect(view, "/ingestions")
    end

    test "clicking cancel warns of unsaved changes", %{curator_conn: conn, ingestion: ingestion} do
      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")

      editor = find_live_child(view, "extract_step_form_editor")

      render_change(editor, "update_new_step_type", %{"value" => "http"})
      render_click(editor, "add-extract-step")

      render_click(view, "save")

      updated_andi_ingestion = Andi.InputSchemas.Ingestions.get(ingestion.id)
      extract_step_id = get_extract_step_id(updated_andi_ingestion, 0)
      es_form = element(editor, "#step-#{extract_step_id} form")

      render_change(es_form, %{"form_data" => %{"action" => "GET", "url" => "cam.com", "body" => ""}})

      render_change(view, "cancel-edit", %{})
      html = render(view)

      refute Enum.empty?(find_elements(html, ".unsaved-changes-modal--visible"))

      render_change(view, "force-cancel-edit", %{})

      assert_redirect(view, "/ingestions")
    end

    test "are able to be deleted", %{curator_conn: conn, ingestion: ingestion} do
      assert {:ok, view, _html} = live(conn, "#{@url_path}/#{ingestion.id}")
      delete_ingestion_in_ui(view)

      eventually(fn ->
        assert Ingestions.get(ingestion.id) == nil
        assert {:ok, nil} = IngestionStore.get(ingestion.id)
      end)
    end

    test "when deleted redirect to #{@url_path}", %{curator_conn: conn, ingestion: ingestion} do
      assert {:ok, view, _html} = live(conn, "#{@url_path}/#{ingestion.id}")
      delete_ingestion_in_ui(view)

      assert_redirected(view, @url_path)
    end

    test "when deleted an audit log is captured with the corresponding email", %{curator_conn: conn, ingestion: ingestion} do
      assert {:ok, view, _html} = live(conn, "#{@url_path}/#{ingestion.id}")
      delete_ingestion_in_ui(view)

      eventually(fn ->
        events = AuditEvents.get_all_of_type(ingestion_delete())

        assert [audit_event] = Enum.filter(events, fn ele -> Map.get(ele.event, "id") == ingestion.id end)
        assert "bob@example.com" == audit_event.user_id
      end)

      assert_redirected(view, @url_path)
    end

    test "success message is displayed when form data is saved", %{curator_conn: conn} do
      smrt_ingestion = TDG.create_ingestion(%{targetDataset: nil})

      {:ok, ingestion} =
        InputConverter.smrt_ingestion_to_draft_changeset(smrt_ingestion)
        |> Ingestions.save()

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")

      assert get_text(html, "#snackbar") == ""

      render_change(view, :save, %{})
      html = render(view)

      refute Enum.empty?(find_elements(html, "#snackbar.success-message"))
      assert get_text(html, "#snackbar") == "Saved successfully. You may need to fix errors before publishing."
    end

    test "saving form as draft does not send brook event", %{curator_conn: conn} do
      allow(AndiWeb.Endpoint.broadcast_from(any(), any(), any(), any()), return: :ok, meck_options: [:passthrough])
      allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)
      smrt_ingestion = TDG.create_ingestion(%{targetDataset: nil})

      {:ok, ingestion} =
        InputConverter.smrt_ingestion_to_draft_changeset(smrt_ingestion)
        |> Ingestions.save()

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")

      render_change(view, :save, %{})

      refute_called Brook.Event.send(any(), any(), any(), any())
    end

    test "publishing a valid ingestion send an ingestion_update event", %{curator_conn: conn, ingestion: ingestion} do
      allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")
      render_click(view, "publish")

      assert_called Brook.Event.send(any(), ingestion_update(), any(), %{id: ingestion.id})
    end

    test "publishing a valid ingestion sets it's status to \"published\"", %{curator_conn: conn, ingestion: ingestion} do
      allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")
      render_click(view, "publish")

      published_ingestion = Ingestions.get(ingestion.id)
      assert published_ingestion.submissionStatus == :published
    end

    test "publishing a valid ingestion creates an audit log with corresponding email", %{curator_conn: conn, ingestion: ingestion} do
      allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)
      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")
      render_click(view, "publish")

      eventually(fn ->
        events = AuditEvents.get_all_of_type(ingestion_update())

        assert [audit_event] = Enum.filter(events, fn ele -> Map.get(ele.event, "id") == ingestion.id end)
        assert "bob@example.com" == audit_event.user_id
      end)
    end

    test "ingestion form edits are included in publish event", %{curator_conn: conn, ingestion: ingestion} do
      allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)

      new_name = "new_name"

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")

      form_data = %{"name" => new_name}
      metadata_view = find_live_child(view, "ingestion_metadata_form_editor")
      html = render_change(metadata_view, "validate", %{"form_data" => form_data})

      render_click(view, "publish")

      assert_called Brook.Event.send(any(), ingestion_update(), any(), %{name: new_name})
    end

    test "attempting to publish an invalid ingestion does *not* send an ingestion_update event", %{curator_conn: conn} do
      allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)

      smrt_ingestion = TDG.create_ingestion(%{targetDataset: nil})

      {:ok, ingestion} =
        InputConverter.smrt_ingestion_to_draft_changeset(smrt_ingestion)
        |> Ingestions.save()

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")
      render_click(view, "publish")

      refute_called Brook.Event.send(any(), any(), any(), any())
    end

    test "adding a transformation and cancelling prompts a confirmation", %{curator_conn: conn} do
      allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)
      smrt_ingestion = TDG.create_ingestion(%{targetDataset: nil})

      {:ok, ingestion} =
        InputConverter.smrt_ingestion_to_draft_changeset(smrt_ingestion)
        |> Ingestions.save()

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")

      find_live_child(view, "transformations_form_editor")
      |> element("#add-transformation")
      |> render_click()

      element(view, ".btn--cancel")
      |> render_click()

      assert element(view, ".unsaved-changes-modal--visible")
             |> has_element?()
    end

    defp delete_ingestion_in_ui(view) do
      view |> element("#ingestion-delete-button") |> render_click
      view |> element(".delete-button") |> render_click
    end

    defp get_extract_step_id(ingestion, index) do
      ingestion
      |> Andi.InputSchemas.StructTools.to_map()
      |> Map.get(:extractSteps)
      |> Enum.at(index)
      |> Map.get(:id)
    end
  end
end
