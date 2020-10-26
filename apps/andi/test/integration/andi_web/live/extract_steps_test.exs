defmodule AndiWeb.ExtractStepsTest do
  @moduledoc false

  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase

  @moduletag shared_data_connection: true

  import Phoenix.LiveViewTest
  import FlokiHelpers,
    only: [
      get_attributes: 3,
      get_value: 2,
      get_values: 2,
      get_select: 2,
      get_select_first_option: 2,
      get_text: 2,
      find_elements: 2
    ]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Datasets

  @url_path "/datasets/"

  test "given a dataset with many extract steps, all steps are rendered", %{conn: conn} do
    smrt_dataset = TDG.create_dataset(%{technical: %{extractSteps: [%{type: "http"}, %{type: "http"}]}})
    {:ok, andi_dataset} = Datasets.update(smrt_dataset)

    assert {:ok, view, html} = live(conn, @url_path <> andi_dataset.id)

    assert find_elements(html, ".extract-step-container") |> Enum.count == 2
  end
end
