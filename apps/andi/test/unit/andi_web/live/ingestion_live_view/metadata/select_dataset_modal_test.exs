defmodule AndiWeb.IngestionLiveView.SelectDatasetModalTest do
  use AndiWeb.Test.AuthConnCase.UnitCase
  use Placebo
  import Phoenix.ConnTest
  alias Andi.Schemas.User

  import Phoenix.LiveViewTest
  import FlokiHelpers, only: [get_text: 2]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Ingestions
  alias Andi.InputSchemas.Datasets.Dataset
  alias Andi.InputSchemas.Datasets
  alias AndiWeb.IngestionLiveView.MetadataForm

  @endpoint AndiWeb.Endpoint
  @user UserHelpers.create_user()

  defp allowAuthUser do
    allow(Andi.Repo.get_by(Andi.Schemas.User, any()), return: @user)
    allow(User.get_all(), return: [@user])
    allow(User.get_by_subject_id(any()), return: @user)
  end

  setup do
    allowAuthUser()
    []
  end

  setup %{auth_conn_case: auth_conn_case} do
    auth_conn_case.disable_revocation_list.()
    :ok
  end

  describe "Basic dataset search load" do
    test "shows \"No Matching Datasets\" when there are no rows to show" do
      ingestion = %Andi.InputSchemas.Ingestion{
        id: "id",
        targetDataset: "dataset_id",
        cadence: "once",
        sourceFormat: "csv",
        extractSteps: [],
        schema: []
      }

      allow(Andi.InputSchemas.Datasets.get_all(), return: [])
      allow(Ingestions.update(any()), return: ingestion)
      allow(Ingestions.get(any()), return: ingestion)
      allow(Andi.Repo.get(Andi.InputSchemas.Ingestion, any()), return: [])
      allow(Andi.InputSchemas.Datasets.get(any()), return: nil)

      assert {:ok, view, html} = live_isolated(build_conn(), MetadataForm, session: %{"ingestion" => ingestion})

      select_dataset_button = find_select_dataset_button(view)
      render_click(select_dataset_button)

      assert get_text(html, ".search-table__cell") =~ "No Matching Datasets"
    end

    test "represents a dataset when one exists" do
      ingestion = %Andi.InputSchemas.Ingestion{
        id: "id",
        targetDataset: "dataset_id",
        cadence: "once",
        sourceFormat: "csv",
        extractSteps: [],
        schema: []
      }

      dataset = TDG.create_dataset(%{})

      allow(Andi.Repo.all(any()), return: [%Dataset{business: %{dataTitle: "Noodles", orgTitle: "Happy", keywords: ["Soup"]}}])
      allow(Ingestions.update(any()), return: ingestion)
      allow(Ingestions.get(any()), return: ingestion)
      allow(Datasets.get(any()), return: dataset)
      allow(Andi.Repo.get(Andi.InputSchemas.Ingestion, any()), return: [])
      allow(Andi.InputSchemas.Datasets.get(any()), return: nil)

      assert {:ok, view, html} = live_isolated(build_conn(), MetadataForm, session: %{"ingestion" => ingestion})

      select_dataset_button = find_select_dataset_button(view)
      render_click(select_dataset_button)

      html = render_submit(view, "datasets-search", %{"search-value" => "Noodles"})

      assert get_text(html, ".search-table__cell") =~ "Noodles"
      assert get_text(html, ".search-table__cell") =~ "Happy"
      assert get_text(html, ".search-table__cell") =~ "Soup"
    end

    test "represents multiple datasets" do
      ingestion = %Andi.InputSchemas.Ingestion{
        id: "id",
        targetDataset: "dataset_id",
        cadence: "once",
        sourceFormat: "csv",
        extractSteps: [],
        schema: []
      }

      allow(Andi.Repo.all(any()),
        return: [
          %Dataset{business: %{dataTitle: "Noodles", orgTitle: "Happy", keywords: ["Soup"]}},
          %Dataset{business: %{dataTitle: "Flowers", orgTitle: "Gardener", keywords: ["Pretty"]}}
        ]
      )

      allow(Ingestions.update(any()), return: ingestion)
      allow(Ingestions.get(any()), return: ingestion)
      allow(Andi.Repo.get(Andi.InputSchemas.Ingestion, any()), return: [])
      allow(Andi.InputSchemas.Datasets.get(any()), return: nil)

      assert {:ok, view, html} = live_isolated(build_conn(), MetadataForm, session: %{"ingestion" => ingestion})

      select_dataset_button = find_select_dataset_button(view)
      render_click(select_dataset_button)

      html = render_submit(view, "datasets-search", %{"search-value" => "Noodles"})

      assert get_text(html, ".search-table__cell") =~ "Noodles"
      assert get_text(html, ".search-table__cell") =~ "Happy"
      assert get_text(html, ".search-table__cell") =~ "Soup"
      assert get_text(html, ".search-table__cell") =~ "Flowers"
      assert get_text(html, ".search-table__cell") =~ "Gardener"
      assert get_text(html, ".search-table__cell") =~ "Pretty"
    end

    test "only allows one dataset to be selected" do
      ingestion = %Andi.InputSchemas.Ingestion{
        id: "id",
        targetDataset: "dataset_id",
        cadence: "once",
        sourceFormat: "csv",
        extractSteps: [],
        schema: []
      }

      allow(Andi.Repo.all(any()),
        return: [
          %Dataset{id: "1", business: %{dataTitle: "Noodles", orgTitle: "Happy", keywords: ["Soup"]}},
          %Dataset{id: "2", business: %{dataTitle: "Flowers", orgTitle: "Gardener", keywords: ["Pretty"]}}
        ]
      )

      allow(Ingestions.update(any()), return: ingestion)
      allow(Ingestions.get(any()), return: ingestion)
      allow(Andi.Repo.get(Andi.InputSchemas.Ingestion, any()), return: [])

      allow(Andi.InputSchemas.Datasets.get(any()),
        return: %Dataset{id: "1", business: %{dataTitle: "Noodles", orgTitle: "Happy", keywords: ["Soup"]}}
      )

      assert {:ok, view, html} = live_isolated(build_conn(), MetadataForm, session: %{"ingestion" => ingestion})

      select_dataset_button = find_select_dataset_button(view)
      render_click(select_dataset_button)

      render_submit(view, "datasets-search", %{"search-value" => "Noodles"})

      # Select the first dataset
      select_search_result = element(view, "[phx-value-id=1]")
      html = render_click(select_search_result)

      assert get_text(html, "[phx-value-id=2]") =~ "Select"
      assert get_text(html, "[phx-value-id=1]") =~ "Remove"

      # Select the second dataset
      select_search_result = element(view, "[phx-value-id=2]")
      html = render_click(select_search_result)

      assert get_text(html, "[phx-value-id=1]") =~ "Select"
      assert get_text(html, "[phx-value-id=2]") =~ "Remove"
    end
  end

  defp find_select_dataset_button(view) do
    element(view, ".btn", "Select Dataset")
  end
end