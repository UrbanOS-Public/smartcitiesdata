defmodule AndiWeb.Extracts3StepFormTest do
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
  alias Andi.InputSchemas.Ingestions

  @url_path "/ingestions/"
  @moduletag shared_data_connection: true
  @instance_name Andi.instance_name()

  describe "s3 step form edit" do
    setup %{conn: conn} do
      dataset = TDG.create_dataset(%{name: "sample_dataset"})
      ingestion_id = UUID.uuid4()
      s3_step = %{context: %{url: "bar.com"}, id: UUID.uuid4(), type: "s3", sequence: 0}
      ingestion = TDG.create_ingestion(%{id: ingestion_id, targetDatasets: [dataset.id], name: "sample_ingestion", extractSteps: [s3_step]})

      Brook.Event.send(@instance_name, dataset_update(), :andi, dataset)
      Brook.Event.send(@instance_name, ingestion_update(), :andi, ingestion)

      eventually(fn ->
        assert Ingestions.get(ingestion.id) != nil
      end)

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")
      [view: view, html: html, s3_step: s3_step]
    end

    test "url field can be altered and saved", %{
      view: view,
      html: html,
      s3_step: s3_step
    } do
      new_url = "https://example.com"

      form_data = %{
        "url" => new_url
      }

      view
      |> form("##{s3_step.id}", form_data: form_data)
      |> render_change()

      html = render(view)
      assert get_value(html, "##{s3_step.id}_s3_url") == new_url
    end

    test "url field shows an error if blank", %{
      view: view,
      html: html,
      s3_step: s3_step
    } do
      new_url = ""

      form_data = %{
        "url" => new_url
      }

      view
      |> form("##{s3_step.id}", form_data: form_data)
      |> render_change()

      html = render(view)
      assert get_text(html, "##{s3_step.id}_s3_url_error") == "Please enter a valid url"
    end
  end
end
