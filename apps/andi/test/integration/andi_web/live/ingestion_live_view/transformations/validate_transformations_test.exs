defmodule AndiWeb.IngestionLiveView.Transformations.ValidateTransformationsTest do
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
        targetDatasets: [dataset.id],
        name: "sample_ingestion",
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

  test "shows invalid status when field is invalid", %{view: view, ingestion: ingestion} do
    transformation = Enum.find(ingestion.transformations, fn transformation -> transformation.type == "concatenation" end)

    form_data = %{"name" => ""}

    view
    |> form("##{transformation.id}", form_data: form_data)
    |> render_change()

    html = render(view)
    assert element(view, ".component-number--invalid") |> has_element?
    assert element(view, ".component-number-status--invalid") |> has_element?

    # expand_transformation_editor(view)
    # transformation_id = add_transformation(view)
    # data = %{"name" => "", "id" => transformation_id, "type" => "", "sourceField" => ""}
    # edit_transformation(view, transformation_id, data)
    # minimize_transformation_editor(view)

    # eventually(fn ->
    #
    # end)
  end

  test "shows valid status when all fields are valid", %{view: view} do
    assert element(view, ".component-number--valid") |> has_element?
    assert element(view, ".component-number-status--valid") |> has_element?
  end
end
