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
      find_elements: 2,
      get_attributes: 3,
      get_text: 2,
      get_value: 2,
      get_select: 2
    ]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Ingestions
  alias AndiWeb.Helpers.FormTools
  alias Andi.InputSchemas.InputConverter
  alias AndiWeb.InputSchemas.FinalizeFormSchema

  @endpoint AndiWeb.Endpoint
  @url_path "/ingestions/"

  @moduletag shared_data_connection: true
  @instance_name Andi.instance_name()

  describe "ingestions metadata form edit" do
    setup %{conn: conn} do
      dataset = TDG.create_dataset(%{name: "sample_dataset"})
      dataset2 = TDG.create_dataset(%{name: "sample_dataset2"})
      ingestion_id = UUID.uuid4()
      ingestion = TDG.create_ingestion(%{id: ingestion_id, targetDatasets: [dataset.id, dataset2.id], name: "sample_ingestion"})

      Brook.Event.send(@instance_name, dataset_update(), :andi, dataset)
      Brook.Event.send(@instance_name, dataset_update(), :andi, dataset2)
      Brook.Event.send(@instance_name, ingestion_update(), :andi, ingestion)

      eventually(fn ->
        assert Ingestions.get(ingestion.id) != nil
      end)

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")
      [ingestion: ingestion, view: view, html: html, dataset: dataset, dataset2: dataset2, conn: conn]
    end

    test "name field defaults to it's existing name", %{
      view: view,
      html: html,
      ingestion: ingestion
    } do
      assert get_value(html, "#ingestion_metadata_form_name") == ingestion.name
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

      view
      |> form("#ingestion_metadata_form", form_data: form_data)
      |> render_change()

      html = render(view)
      assert get_value(html, "#ingestion_metadata_form_name") == new_name
    end

    test "name field shows an error if blank", %{
      view: view,
      html: html,
      ingestion: ingestion
    } do
      form_data = %{
        "name" => ""
      }

      view
      |> form("#ingestion_metadata_form", form_data: form_data)
      |> render_change()

      html = render(view)
      assert get_text(html, "#name-error-msg") == "Please enter a valid name."
    end

    test "source format field defaults to its existing value", %{
      view: view,
      html: html,
      ingestion: ingestion
    } do
      current_select_value = get_select(html, "#ingestion_metadata_form_sourceFormat") |> Tuple.to_list()
      assert ingestion.sourceFormat in current_select_value
    end

    test "source format field can be altered and saved", %{
      view: view,
      html: html,
      ingestion: ingestion
    } do
      new_source_format = "text/xml"

      form_data = %{
        "sourceFormat" => new_source_format
      }

      view
      |> form("#ingestion_metadata_form", form_data: form_data)
      |> render_change()

      html = render(view)
      current_select_value = get_select(html, "#ingestion_metadata_form_sourceFormat") |> Tuple.to_list()

      assert new_source_format in current_select_value
    end

    test "source format field shows an error if blank", %{
      view: view,
      html: html,
      ingestion: ingestion
    } do
      form_data = %{
        "sourceFormat" => ""
      }

      view
      |> form("#ingestion_metadata_form", form_data: form_data)
      |> render_change()

      html = render(view)
      error_message = get_text(html, "#sourceFormat-error-msg")

      assert error_message == "Please select a valid source format."
    end

    test "dataset name field defaults to it's existing association and sorts names alphabetically", %{
      view: view,
      html: html,
      ingestion: ingestion,
      dataset: dataset,
      dataset2: dataset2
    } do
      sorted_titles = Enum.sort([dataset.business.dataTitle, dataset2.business.dataTitle]) |> Enum.join(", ")
      assert get_value(html, "#ingestion_metadata_form_targetDatasetNames") == sorted_titles
    end

    test "can close dataset modal", %{
      view: view,
      html: html,
      ingestion: ingestion
    } do
      assert Enum.empty?(find_elements(html, ".manage-datasets-modal--visible"))

      html =
        view
        |> element("#open-select-dataset-modal")
        |> render_click()

      refute Enum.empty?(find_elements(html, ".manage-datasets-modal--visible"))

      html =
        view
        |> element("#close-select-dataset-modal")
        |> render_click()

      html = render(view)

      assert Enum.empty?(find_elements(html, ".manage-datasets-modal--visible"))
    end

    test "can not edit source format for published ingestion", %{
      view: view,
      html: html,
      ingestion: ingestion,
      conn: conn
    } do
      {:ok, dataset} =
        TDG.create_dataset(%{name: "sample_dataset", submissionStatus: :published})
        |> Datasets.update()

      eventually(fn ->
        andi_dataset = Datasets.get(dataset.id)
        assert andi_dataset.id == dataset.id
      end)

      {:ok, ingestion} =
        TDG.create_ingestion(%{targetDatasets: [dataset.id], name: "testing123"})
        |> Ingestions.update()

      Ingestions.update_submission_status(ingestion.id, :published)

      eventually(fn ->
        ing = Ingestions.get(ingestion.id)
        assert ing.submissionStatus == :published
      end)

      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)

      refute Enum.empty?(get_attributes(html, "#ingestion_metadata_form_sourceFormat", "disabled"))
    end
  end

  test "topLevelSelector is read only when sourceFormat is not xml nor json", %{conn: conn} do
    {:ok, dataset} =
      TDG.create_dataset(%{name: "sample_dataset", submissionStatus: :published})
      |> Datasets.update()

    eventually(fn ->
      andi_dataset = Datasets.get(dataset.id)
      assert andi_dataset.id == dataset.id
    end)

    {:ok, ingestion} =
      TDG.create_ingestion(%{targetDatasets: [dataset.id], submissionStatus: :published, sourceFormat: "text/csv"})
      |> Ingestions.update()

    assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)

    refute Enum.empty?(get_attributes(html, ".metadata-form__top-level-selector input", "readonly"))
  end

  defp find_select_dataset_btn(view) do
    element(view, ".btn", "Select Dataset")
  end
end
