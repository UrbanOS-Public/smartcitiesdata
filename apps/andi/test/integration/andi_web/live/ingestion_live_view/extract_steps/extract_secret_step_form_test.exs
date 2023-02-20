defmodule AndiWeb.ExtractSecretStepFormTest do
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

  describe "secret step form edit" do
    setup %{conn: conn} do
      dataset = TDG.create_dataset(%{name: "sample_dataset"})
      ingestion_id = UUID.uuid4()
      secret_step = %{context: %{destination: "foo", url: "bar.com", path: ["path"], cacheTtl: 500}, id: UUID.uuid4(), type: "secret", sequence: 0}
      ingestion = TDG.create_ingestion(%{id: ingestion_id, targetDataset: dataset.id, name: "sample_ingestion", extractSteps: [secret_step]})

      Brook.Event.send(@instance_name, dataset_update(), :andi, dataset)
      Brook.Event.send(@instance_name, ingestion_update(), :andi, ingestion)

      eventually(fn ->
        assert Ingestions.get(ingestion.id) != nil
      end)

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")
      [view: view, html: html, secret_step: secret_step]
    end

    test "destination field can be altered and saved", %{
      view: view,
      html: html,
      secret_step: secret_step
    } do
      new_destination = "new_destination"

      form_data = %{
        "destination" => new_destination
      }

      view
      |> form("##{secret_step.id}", form_data: form_data)
      |> render_change()

      html = render(view)
      assert get_value(html, "##{secret_step.id}_secret_destination") == new_destination
    end

    test "destination field shows an error if blank", %{
      view: view,
      html: html,
      secret_step: secret_step
    } do
      new_destination = ""

      form_data = %{
        "destination" => new_destination
      }

      view
      |> form("##{secret_step.id}", form_data: form_data)
      |> render_change()

      html = render(view)
      assert get_text(html, "#destination-error-msg") == "Please enter a valid destination."
    end
  end
end
