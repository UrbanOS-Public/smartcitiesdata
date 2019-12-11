defmodule AndiWeb.EditLiveViewTest do
  use AndiWeb.ConnCase
  use Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Andi.DatasetCache

  alias SmartCity.TestDataGenerator, as: TDG

  @url_path "/datasets/"

  setup do
    GenServer.call(DatasetCache, :reset)
  end

  describe "Enter Metadata" do
    test "display Level of Access as public when private is false", %{conn: conn} do
      dataset = TDG.create_dataset(%{technical: %{private: false}})
      DatasetCache.put(dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)
      [subject] = Floki.find(html, "#metadata_private") |> Floki.attribute("value")

      assert subject =~ "Public"
    end

    test "display Level of Access as private when private is true", %{conn: conn} do
      dataset = TDG.create_dataset(%{technical: %{private: true}})
      DatasetCache.put(dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)
      [subject] = Floki.find(html, "#metadata_private") |> Floki.attribute("value")

      assert subject =~ "Private"
    end

    test "adds commas between keywords", %{conn: conn} do
      dataset = TDG.create_dataset(%{business: %{keywords: ["one", "two", "three"]}})
      DatasetCache.put(dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)
      [subject] = Floki.find(html, "#metadata_keywords") |> Floki.attribute("value")

      assert subject =~ "one, two, three"
    end

    test "should show empty string if keywords is nil", %{conn: conn} do
      dataset = TDG.create_dataset(%{business: %{keywords: nil}})
      DatasetCache.put(dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)
      [subject] = Floki.find(html, "#metadata_keywords") |> Floki.attribute("value")

      assert subject == ""
    end

    test "displays all other fields", %{conn: conn} do
      dataset = TDG.create_dataset(%{business: %{description: "A description with no special characters"}})
      DatasetCache.put(dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)

      assert get_value(html, "#metadata_title") == dataset.business.dataTitle
      assert Floki.find(html, "#metadata_description") |> Floki.text() =~ dataset.business.description
      assert get_value(html, "#metadata_format") == dataset.technical.sourceFormat
      assert get_value(html, "#metadata_contactName") == dataset.business.contactName
      assert get_value(html, "#metadata_contactEmail") == dataset.business.contactEmail
      assert get_value(html, "#metadata_release-date") == dataset.business.issuedDate
      assert get_value(html, "#metadata_license") == dataset.business.license
      assert get_value(html, "#metadata_update-frequency") == dataset.business.publishFrequency
      assert get_value(html, "#metadata_modifiedDate") == dataset.business.modifiedDate
      assert get_value(html, "#metadata_spatial") == dataset.business.spatial
      assert get_value(html, "#metadata_temporal") == dataset.business.temporal
      assert get_value(html, "#metadata_orgTitle") == dataset.business.orgTitle
      assert get_value(html, "#metadata_language") == dataset.business.language
      assert get_value(html, "#metadata_homepage") == dataset.business.homepage
    end
  end

  describe "edit medidata" do
    test "Error should display if ID is empty", %{conn: conn} do
      dataset = TDG.create_dataset(%{business: %{dataTitle: ""}})
      DatasetCache.put(dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)

      assert get_value(html, "#metadata_title") == ""
    end
  end

  defp get_value(html, id) do
    Floki.find(html, id) |> Floki.attribute("value") |> List.first()
  end
end
