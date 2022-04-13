defmodule AndiWeb.EditIngestionLiveView.FinalizeFormTest do
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
      get_attributes: 3,
      get_values: 2,
      find_elements: 2
    ]

  alias SmartCity.TestDataGenerator, as: TDG
  # alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Ingestions
  alias AndiWeb.Helpers.FormTools
  alias Andi.InputSchemas.InputConverter
  alias AndiWeb.InputSchemas.FinalizeFormSchema

  @endpoint AndiWeb.Endpoint
  @url_path "/ingestions/"

  @moduletag shared_data_connection: true
  @instance_name Andi.instance_name()

  describe "one-time ingestion" do
    setup %{conn: conn} do
      ingestion = create_ingestion_with_cadence("once")
      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)

      [
        view: view,
        html: html
      ]
    end

    test "shows the Immediate ingestion button selected", %{html: html} do
      refute Enum.empty?(get_attributes(html, "#form_data_cadence_once", "checked"))
    end

    test "does not show cron scheduler", %{html: html} do
      assert Enum.empty?(find_elements(html, ".finalize-form__scheduler--visible"))
      refute Enum.empty?(find_elements(html, ".finalize-form__scheduler--hidden"))
    end
  end

  defp create_ingestion_with_cadence(cadence) do
    dataset = TDG.create_dataset(%{})
    ingestion = TDG.create_ingestion(%{targetDataset: dataset.id, cadence: cadence})

    Brook.Event.send(@instance_name, dataset_update(), :andi, dataset)
    Brook.Event.send(@instance_name, ingestion_update(), :andi, ingestion)

    eventually(fn ->
      assert Ingestions.get(ingestion.id) != nil
    end)

    Ingestions.get(ingestion.id)
  end
end
