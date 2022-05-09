defmodule AndiWeb.IngestionLiveView.MetadataFormTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  use Placebo
  import Checkov

  import Phoenix.LiveViewTest
  import SmartCity.Event, only: [ingestion_update: 0, dataset_update: 0]
  import SmartCity.TestHelper, only: [eventually: 1]

  import FlokiHelpers,
    only: [
      get_text: 2,
      get_value: 2
    ]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Ingestions
  alias AndiWeb.Helpers.FormTools
  alias Andi.InputSchemas.InputConverter
  alias AndiWeb.InputSchemas.FinalizeFormSchema

  @endpoint AndiWeb.Endpoint
  @url_path "/ingestions/"

  @moduletag shared_data_connection: true
  @instance_name Andi.instance_name()

  describe "ingestions edit" do
    setup %{conn: conn} do
      dataset = TDG.create_dataset(%{name: "sample_dataset"})
      ingestion_id = UUID.uuid4()
      ingestion = TDG.create_ingestion(%{id: ingestion_id, targetDataset: dataset.id, name: "sample_ingestion"})

      Brook.Event.send(@instance_name, dataset_update(), :andi, dataset)
      Brook.Event.send(@instance_name, ingestion_update(), :andi, ingestion)

      eventually(fn ->
        assert Ingestions.get(ingestion.id) != nil
      end)

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")
      [ingestion: ingestion, view: view, html: html, dataset: dataset]
    end

    test "name field defaults to it's existing name", %{
      view: view,
      html: html,
      ingestion: ingestion
    } do
      assert get_value(html, "#form_data_name") == ingestion.name
    end

    test "name field can be altered and saved", %{
      view: view,
      html: html,
      ingestion: ingestion
    } do
      new_name = "new_name"

      form_data = %{
        "name" => new_name
      }

      metadata_view = find_live_child(view, "ingestion_metadata_form_editor")
      render_change(metadata_view, "validate", %{"form_data" => form_data})
      render_change(view, "save")

      html = render(view)
      assert get_value(html, "#form_data_name") == new_name
    end

    @tag :skip
    test "name field reports invalid if left blank", %{
      view: view,
      html: html,
      ingestion: ingestion
    } do
    end

    @tag :skip
    test "dataset name field defaults to it's existing association", %{
      view: view,
      html: html,
      ingestion: ingestion
    } do
    end

    @tag :skip
    test "dataset name field reports invalid if left blank", %{
      view: view,
      html: html,
      ingestion: ingestion
    } do
    end

    @tag :skip
    test "dataset name field can be altered and saved", %{
      view: view,
      html: html,
      ingestion: ingestion
    } do
    end

    @tag :skip
    test "add dataset button opens the add a dataset modal", %{
      view: view,
      html: html,
      ingestion: ingestion
    } do
    end

    @tag :skip
    test "source format field defaults to an empty value", %{
      view: view,
      html: html,
      ingestion: ingestion
    } do
    end

    @tag :skip
    test "source format field reports as invalid if left empty", %{
      curator_conn: conn,
      ingestion: ingestion
    } do
    end

    @tag :skip
    test "source format field can be altered and saved", %{
      view: view,
      html: html,
      ingestion: ingestion
    } do
    end
  end
end
