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
      [subject] = Floki.find(html, "#dataset_schema_technical_private") |> Floki.attribute("value")

      assert subject =~ "Public"
    end

    test "display Level of Access as private when private is true", %{conn: conn} do
      dataset = TDG.create_dataset(%{technical: %{private: true}})
      DatasetCache.put(dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)
      [subject] = Floki.find(html, "#dataset_schema_technical_private") |> Floki.attribute("value")

      assert subject =~ "Private"
    end

    test "adds commas between keywords", %{conn: conn} do
      dataset = TDG.create_dataset(%{business: %{keywords: ["one", "two", "three"]}})
      DatasetCache.put(dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)
      [subject] = Floki.find(html, "#dataset_schema_business_keywords") |> Floki.attribute("value")

      assert subject =~ "one, two, three"
    end

    test "should show empty string if keywords is nil", %{conn: conn} do
      dataset = TDG.create_dataset(%{business: %{keywords: nil}})
      DatasetCache.put(dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)
      [subject] = Floki.find(html, "#dataset_schema_business_keywords") |> Floki.attribute("value")

      assert subject == ""
    end

    # test "should not add additional commas", %{conn: conn} do
    #   dataset = TDG.create_dataset(%{business: %{keywords: nil}})
    #   DatasetCache.put(dataset)

    #   assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)
    #   [subject] = Floki.find(html, "#dataset_schema_business_keywords") |> Floki.attribute("value")

    #   assert false
    # end

    test "displays all other fields", %{conn: conn} do
      dataset = TDG.create_dataset(%{business: %{description: "A description with no special characters"}})
      DatasetCache.put(dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)
      assert get_value(html, "#dataset_schema_business_dataTitle") == dataset.business.dataTitle
      assert get_text(html, "#dataset_schema_business_description") == dataset.business.description
      assert get_value(html, "#dataset_schema_technical_sourceFormat") == dataset.technical.sourceFormat
      assert get_value(html, "#dataset_schema_business_contactName") == dataset.business.contactName
      assert get_value(html, "#dataset_schema_business_contactEmail") == dataset.business.contactEmail
      assert get_value(html, "#dataset_schema_business_release-date") == dataset.business.issuedDate
      assert get_value(html, "#dataset_schema_business_license") == dataset.business.license
      assert get_value(html, "#dataset_schema_business_update-frequency") == dataset.business.publishFrequency
      assert get_value(html, "#dataset_schema_business_modifiedDate") == dataset.business.modifiedDate
      assert get_value(html, "#dataset_schema_business_spatial") == dataset.business.spatial
      assert get_value(html, "#dataset_schema_business_temporal") == dataset.business.temporal
      assert get_value(html, "#dataset_schema_business_orgTitle") == dataset.business.orgTitle
      assert get_value(html, "#dataset_schema_business_language") == dataset.business.language
      assert get_value(html, "#dataset_schema_business_homepage") == dataset.business.homepage
    end
  end

  describe "edit metadata" do
    test "accessibility level must be public or private" do
      # assert_error_message(TDG.create_dataset(%{technical: %{private: ""}}), "Access Level is required.")
    end

    test "All required fields display proper error message", %{conn: conn} do
      assert_error_message(
        conn,
        TDG.create_dataset(%{business: %{dataTitle: ""}}),
        :dataTitle,
        "Dataset Title is required."
      )

      assert_error_message(
        conn,
        TDG.create_dataset(%{business: %{description: ""}}),
        :description,
        "Description is required."
      )

      assert_error_message(
        conn,
        TDG.create_dataset(%{business: %{contactName: ""}}),
        :contactName,
        "Maintainer Name is required."
      )

      assert_error_message(
        conn,
        TDG.create_dataset(%{business: %{contactEmail: ""}}),
        :contactEmail,
        "Maintainer Email is required."
      )

      assert_error_message(
        conn,
        TDG.create_dataset(%{business: %{issuedDate: ""}}),
        :issuedDate,
        "Release Date is required."
      )

      assert_error_message(conn, TDG.create_dataset(%{business: %{license: ""}}), :license, "License is required.")

      dataset = TDG.create_dataset(%{})
      new_tech = Map.put(dataset.technical, :sourceFormat, "")
      dataset = Map.put(dataset, :technical, new_tech)

      assert_error_message(
        conn,
        dataset,
        :sourceFormat,
        "Format is required."
      )

      assert_error_message(
        conn,
        TDG.create_dataset(%{business: %{publishFrequency: ""}}),
        :publishFrequency,
        "Publish Frequency is required."
      )

      assert_error_message(
        conn,
        TDG.create_dataset(%{business: %{orgTitle: ""}}),
        :orgTitle,
        "Organization is required."
      )
    end
  end

  defp assert_error_message(conn, dataset, field, error_message) do
    DatasetCache.put(dataset)

    assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)

    assert get_text(html, "##{field}-error-msg") == error_message
  end

  defp get_value(html, id) do
    Floki.find(html, id) |> Floki.attribute("value") |> List.first()
  end

  defp get_text(html, id) do
    Floki.find(html, id) |> Floki.text() |> String.trim()
  end
end
