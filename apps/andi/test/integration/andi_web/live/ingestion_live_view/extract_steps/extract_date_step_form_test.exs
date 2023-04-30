defmodule AndiWeb.ExtractDateStepFormTest do
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

  describe "date step form edit" do
    setup %{conn: conn} do
      dataset = TDG.create_dataset(%{name: "sample_dataset"})
      ingestion_id = UUID.uuid4()

      date_step = %{
        context: %{destination: "foo", deltaTimeUnit: "hours", deltaTimeValue: "5", format: "format"},
        id: UUID.uuid4(),
        type: "date",
        sequence: 0
      }

      ingestion =
        TDG.create_ingestion(%{id: ingestion_id, targetDatasets: [dataset.id], name: "sample_ingestion", extractSteps: [date_step]})

      Brook.Event.send(@instance_name, dataset_update(), :andi, dataset)
      Brook.Event.send(@instance_name, ingestion_update(), :andi, ingestion)

      eventually(fn ->
        assert Ingestions.get(ingestion.id) != nil
      end)

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")
      [view: view, html: html, date_step: date_step]
    end

    test "destination field can be altered and saved", %{
      view: view,
      html: html,
      date_step: date_step
    } do
      new_destination = "new_destination"

      form_data = %{
        "destination" => new_destination
      }

      view
      |> form("##{date_step.id}", form_data: form_data)
      |> render_change()

      html = render(view)
      assert get_value(html, "##{date_step.id}_date_destination") == new_destination
    end

    test "destination field shows an error if blank", %{
      view: view,
      html: html,
      date_step: date_step
    } do
      new_destination = ""

      form_data = %{
        "destination" => new_destination
      }

      view
      |> form("##{date_step.id}", form_data: form_data)
      |> render_change()

      html = render(view)
      assert get_text(html, "##{date_step.id}_date_destination_error") == "Please enter a valid destination."
    end

    test "delta time unit field can be altered and saved", %{
      view: view,
      html: html,
      date_step: date_step
    } do
      new_delta_time_unit = "days"

      form_data = %{
        "deltaTimeUnit" => new_delta_time_unit
      }

      view
      |> form("##{date_step.id}", form_data: form_data)
      |> render_change()

      html = render(view)
      {actual, _} = get_select(html, "##{date_step.id}_date_delta_time_unit")
      assert actual = new_delta_time_unit
    end

    test "delta time value field can be altered and saved", %{
      view: view,
      html: html,
      date_step: date_step
    } do
      new_delta_time_value = "4"

      form_data = %{
        "deltaTimeValue" => new_delta_time_value
      }

      view
      |> form("##{date_step.id}", form_data: form_data)
      |> render_change()

      html = render(view)
      assert get_value(html, "##{date_step.id}_date_delta_time_value") == new_delta_time_value
    end
  end
end
