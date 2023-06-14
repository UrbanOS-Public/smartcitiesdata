defmodule AndiWeb.IngestionLiveView.Transformations.TransformationsStepTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase

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

    transformation1 =
      TDG.create_transformation(%{
        name: "sample",
        type: "concatenation",
        parameters: %{},
        sequence: 1
      })

    transformation2 =
      TDG.create_transformation(%{
        name: "sample2",
        type: "add",
        parameters: %{},
        sequence: 2
      })

    ingestion =
      TDG.create_ingestion(%{
        id: UUID.uuid4(),
        name: "Original",
        targetDatasets: [dataset.id],
        transformations: [transformation1, transformation2]
      })

    Brook.Event.send(@instance_name, dataset_update(), :andi, dataset)
    Brook.Event.send(@instance_name, ingestion_update(), :andi, ingestion)

    eventually(fn ->
      assert Ingestions.get(ingestion.id) != nil
    end)

    assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")
    [view: view, html: html, ingestion: ingestion, conn: conn]
  end

  test "can be expanded and collapsed", %{view: view} do
    view
    |> element("#Transformations-collapsible-header-view")
    |> render_click()

    html = render(view)

    assert element(view, ".component-edit-section--expanded") |> has_element?
    assert element(view, ".component-number--valid") |> has_element?
    assert element(view, ".component-number-status--valid") |> has_element?

    view
    |> element("#Transformations-collapsible-header-view")
    |> render_click()

    html = render(view)

    assert element(view, ".component-edit-section--collapsed") |> has_element?
  end

  test "add transformation creates a new transformation", %{view: view, ingestion: ingestion} do
    view
    |> element("#add-transformation")
    |> render_click()

    html = render(view)

    assert find_elements(html, ".transformation-header") |> Enum.count() == 3
  end

  test "add transformation displays transformation header by default", %{view: view, ingestion: ingestion} do
    view
    |> element("#add-transformation")
    |> render_click()

    html = render(view)

    assert FlokiHelpers.get_text(html, ".transformation-header") =~ "New Transformation"
  end

  test "transformation header displays transformation name", %{html: html, ingestion: ingestion} do
    transformation = Enum.find(ingestion.transformations, fn transformation -> transformation.type == "concatenation" end)
    transformation2 = Enum.find(ingestion.transformations, fn transformation -> transformation.type == "add" end)

    assert FlokiHelpers.get_text(html, ".transformation-header") =~ transformation.name
    assert FlokiHelpers.get_text(html, ".transformation-header") =~ transformation2.name
  end
end
