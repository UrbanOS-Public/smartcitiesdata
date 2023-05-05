defmodule AndiWeb.IngestionLiveView.ExtractSteps.ExtractStepFormTest do
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

  setup %{conn: conn} do
    dataset = TDG.create_dataset(%{name: "sample_dataset"})

    http_extract_step = %{
      type: "http",
      id: UUID.uuid4(),
      context: %{
        action: "GET",
        url: "http://example.com"
      }
    }

    date_extract_step = %{
      type: "date",
      id: UUID.uuid4(),
      context: %{
        destination: "bob_field",
        deltaTimeUnit: "years",
        deltaTimeValue: 5,
        format: "{ISO:Extended}"
      }
    }

    ingestion =
      TDG.create_ingestion(%{
        id: UUID.uuid4(),
        targetDatasets: [dataset.id],
        name: "sample_ingestion",
        extractSteps: [date_extract_step, http_extract_step]
      })

    Brook.Event.send(@instance_name, dataset_update(), :andi, dataset)
    Brook.Event.send(@instance_name, ingestion_update(), :andi, ingestion)

    eventually(fn ->
      assert Ingestions.get(ingestion.id) != nil
    end)

    assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")
    [view: view, html: html, ingestion: ingestion, conn: conn]
  end

  test "given an ingestion with many extract steps, all steps are rendered", %{html: html, ingestion: ingestion} do
    for extract_step <- ingestion.extractSteps do
      assert find_elements(html, "##{extract_step.id}")
    end
  end

  test "when the add step button is pressed, a new step is rendered", %{view: view, ingestion: ingestion} do
    view
    |> form("#extract_addition_form", form: %{"step_type" => "http"})
    |> render_submit()

    html = render(view)
    assert find_elements(html, ".extract-step-container") |> Enum.count() == 3
  end

  test "given an invalid extract http step, the section shows an invalid status", %{ingestion: ingestion, view: view} do
    extract_step = Enum.find(ingestion.extractSteps, fn extract_step -> extract_step.type == "http" end)

    form_data = %{"url" => ""}

    view
    |> form("##{extract_step.id}", form_data: form_data)
    |> render_change()

    html = render(view)
    assert not Enum.empty?(find_elements(html, ".component-number--invalid"))
  end

  test "given an invalid extract date step, the section shows an invalid status", %{ingestion: ingestion, view: view} do
    extract_step = Enum.find(ingestion.extractSteps, fn extract_step -> extract_step.type == "date" end)

    form_data = %{"destination" => ""}

    view
    |> form("##{extract_step.id}", form_data: form_data)
    |> render_change()

    html = render(view)
    assert not Enum.empty?(find_elements(html, ".component-number--invalid"))
  end

  test "given a previously invalid extract step, and it's made valid, the section shows a valid status", %{
    ingestion: ingestion,
    view: view
  } do
    extract_step = Enum.find(ingestion.extractSteps, fn extract_step -> extract_step.type == "http" end)

    form_data = %{"url" => ""}

    view
    |> form("##{extract_step.id}", form_data: form_data)
    |> render_change()

    html = render(view)
    assert not Enum.empty?(find_elements(html, ".component-number--invalid"))

    form_data = %{"action" => "GET", "url" => "http://bob.com"}

    view
    |> form("##{extract_step.id}", form_data: form_data)
    |> render_change()

    html = render(view)
    assert not Enum.empty?(find_elements(html, ".component-number--valid"))
  end

  test "empty extract steps are invalid", %{conn: conn} do
    dataset = TDG.create_dataset(%{name: "sample_dataset"})
    ingestion = TDG.create_ingestion(%{id: UUID.uuid4(), targetDatasets: [dataset.id], name: "sample_ingestion", extractSteps: []})

    Brook.Event.send(@instance_name, dataset_update(), :andi, dataset)
    Brook.Event.send(@instance_name, ingestion_update(), :andi, ingestion)

    eventually(fn ->
      assert Ingestions.get(ingestion.id) != nil
    end)

    {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")

    assert get_text(html, ".extract-steps__error-message") == "Cannot be empty and must end with a http or s3 step"
    assert not Enum.empty?(find_elements(html, ".component-number-status--invalid"))
  end

  test "extract steps without a trailing http or s3 step are invalid", %{conn: conn} do
    dataset = TDG.create_dataset(%{name: "sample_dataset"})

    date_extract_step = %{
      type: "date",
      id: UUID.uuid4(),
      context: %{
        destination: "bob_field",
        deltaTimeUnit: "years",
        deltaTimeValue: 5,
        format: "{ISO:Extended}"
      }
    }

    ingestion =
      TDG.create_ingestion(%{id: UUID.uuid4(), targetDatasets: [dataset.id], name: "sample_ingestion", extractSteps: [date_extract_step]})

    Brook.Event.send(@instance_name, dataset_update(), :andi, dataset)
    Brook.Event.send(@instance_name, ingestion_update(), :andi, ingestion)

    eventually(fn ->
      assert Ingestions.get(ingestion.id) != nil
    end)

    {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")
    assert get_text(html, ".extract-steps__error-message") == "Cannot be empty and must end with a http or s3 step"
    assert not Enum.empty?(find_elements(html, ".component-number-status--invalid"))
  end

  test "validation is updated when steps are added", %{ingestion: ingestion, view: view, html: html} do
    assert not Enum.empty?(find_elements(html, ".component-number-status--valid"))

    form_data = %{step_type: "date"}

    view
    |> form("#extract_addition_form", form: form_data)
    |> render_submit()

    html = render(view)

    assert not Enum.empty?(find_elements(html, ".component-number-status--invalid"))
  end
end
