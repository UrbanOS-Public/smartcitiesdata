defmodule AndiWeb.AccessGroupLiveView.EditIngestionLiveViewTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase

  @moduletag shared_data_connection: true
  @instance_name Andi.instance_name()

  import SmartCity.Event, only: [ingestion_update: 0, ingestion_delete: 0, dataset_update: 0]
  import Placebo
  import Phoenix.LiveViewTest
  import SmartCity.TestHelper, only: [eventually: 1, eventually: 3]

  import FlokiHelpers,
    only: [
      find_elements: 2,
      get_texts: 2,
      get_attributes: 3
    ]

  alias SmartCity.TestDataGenerator, as: TDG

  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Ingestions
  alias Andi.Schemas.AuditEvents
  alias Andi.Services.IngestionStore

  @instance_name Andi.instance_name()

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

    defp delete_ingestion_in_ui(view) do
      view |> element("#ingestion-delete-button") |> render_click
      view |> element(".delete-button") |> render_click
    end
  end
end
