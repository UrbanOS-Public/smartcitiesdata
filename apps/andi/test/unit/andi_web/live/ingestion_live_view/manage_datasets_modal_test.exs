defmodule AndiWeb.IngestionLiveView.ManageDatasetsModalTest do
  use AndiWeb.Test.AuthConnCase.UnitCase
  use Placebo
  alias Andi.Schemas.User

  import Phoenix.LiveViewTest
  import FlokiHelpers, only: [get_text: 2]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Ingestions
  alias Andi.InputSchemas.Ingestion
  alias Andi.InputSchemas.Datasets.Dataset

  @endpoint AndiWeb.Endpoint
  @url_path "/ingestions"
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

  # TODO: use modal-specific selector in front of more generic class selectors

  describe "Basic dataset search load" do
    test "shows \"No Matching Datasets\" when there are no rows to show", %{conn: conn} do
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

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")

      select_dataset_button = find_select_dataset_button(view)
      render_click(select_dataset_button)

      assert get_text(html, ".search-table__cell") =~ "No Matching Datasets"
    end

    test "represents a dataset when one exists", %{conn: conn} do
      ingestion = %Andi.InputSchemas.Ingestion{
        id: "id",
        targetDataset: "dataset_id",
        cadence: "once",
        sourceFormat: "csv",
        extractSteps: [],
        schema: []
      }

      allow(Andi.Repo.all(any()), return: [%Dataset{business: %{dataTitle: "Noodles", orgTitle: "Happy", keywords: ["Soup"]}}])
      allow(Ingestions.update(any()), return: ingestion)
      allow(Ingestions.get(any()), return: ingestion)
      allow(Andi.Repo.get(Andi.InputSchemas.Ingestion, any()), return: [])

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")

      select_dataset_button = find_select_dataset_button(view)
      render_click(select_dataset_button)

      html = render_submit(view, "dataset-search", %{"search-value" => "Noodles"})

      assert get_text(html, ".search-table__cell") =~ "Noodles"
      assert get_text(html, ".search-table__cell") =~ "Happy"
      assert get_text(html, ".search-table__cell") =~ "Soup"
    end

    test "represents multiple datasets", %{conn: conn} do
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

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")

      select_dataset_button = find_select_dataset_button(view)
      render_click(select_dataset_button)

      html = render_submit(view, "dataset-search", %{"search-value" => "Noodles"})

      assert get_text(html, ".search-table__cell") =~ "Noodles"
      assert get_text(html, ".search-table__cell") =~ "Happy"
      assert get_text(html, ".search-table__cell") =~ "Soup"
      assert get_text(html, ".search-table__cell") =~ "Flowers"
      assert get_text(html, ".search-table__cell") =~ "Gardener"
      assert get_text(html, ".search-table__cell") =~ "Pretty"
    end
  end

  defp find_select_dataset_button(view) do
    element(view, ".btn", "Select Dataset")
  end
end
