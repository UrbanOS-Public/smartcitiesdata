defmodule AndiWeb.AccessGroupLiveView.EditIngestionLiveViewTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase

  @moduletag shared_data_connection: true

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
  alias Andi.InputSchemas.Ingestion
  alias Andi.InputSchemas.Ingestions

  @instance_name Andi.instance_name()

  @url_path "/ingestions"

  describe "ingestions" do
    setup do
      dataset = TDG.create_dataset(%{})
      {:ok, _changeset} = Datasets.update(dataset)

      ingestion_id = UUID.uuid4()
      ingestion = TDG.create_ingestion(%{id: ingestion_id, targetDataset: dataset.id})
      {:ok, _changeset} = Ingestions.update(ingestion)

      %{ingestion: ingestion}
    end

    test "are able to be deleted", %{curator_conn: conn, ingestion: ingestion} do
      assert {:ok, view, _html} = live(conn, "#{@url_path}/#{ingestion.id}")
      delete_ingestion_in_ui(view)

      eventually(fn ->
        assert Ingestions.get(ingestion.id) == nil
      end)
    end

    test "when deleted redirect to #{@url_path}", %{curator_conn: conn, ingestion: ingestion} do
      assert {:ok, view, _html} = live(conn, "#{@url_path}/#{ingestion.id}")
      delete_ingestion_in_ui(view)

      assert_redirected(view, @url_path)
    end

    defp delete_ingestion_in_ui(view) do
      view |> element("#ingestion-delete-button") |> render_click
      view |> element(".delete-button") |> render_click
    end
  end
end
