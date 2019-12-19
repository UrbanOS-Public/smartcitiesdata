defmodule AndiWeb.EditLiveViewTest do
  use AndiWeb.ConnCase
  use Phoenix.ConnTest
  use Placebo

  import Phoenix.LiveViewTest
  import Checkov
  import Andi
  import SmartCity.Event, only: [dataset_update: 0]

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
      assert {"false", "Public"} = get_select(html, "#dataset_schema_technical_private")
    end

    test "display Level of Access as private when private is true", %{conn: conn} do
      dataset = TDG.create_dataset(%{technical: %{private: true}})
      DatasetCache.put(dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)
      assert {"true", "Private"} = get_select(html, "#dataset_schema_technical_private")
    end

    test "the default language is set to english", %{conn: conn} do
      dataset = TDG.create_dataset(%{business: %{language: nil}})
      DatasetCache.put(dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)

      assert {"english", "English"} = get_select(html, "#dataset_schema_business_language")
    end

    test "the language is set to spanish", %{conn: conn} do
      dataset = TDG.create_dataset(%{business: %{language: "spanish"}})
      DatasetCache.put(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert {"spanish", "Spanish"} = get_select(html, "#dataset_schema_business_language")
    end

    test "the language is set to english", %{conn: conn} do
      dataset = TDG.create_dataset(%{business: %{language: "english"}})
      DatasetCache.put(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert {"english", "English"} = get_select(html, "#dataset_schema_business_language")
    end

    test "the language is changed from english to spanish", %{conn: conn} do
      dataset = TDG.create_dataset(%{business: %{language: "english"}})
      DatasetCache.put(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      dataset_map = dataset_to_map(dataset) |> put_in([:business, :language], "spanish")

      html = render_change(view, :validate, %{"dataset_schema" => dataset_map})

      assert {"spanish", "Spanish"} = get_select(html, "#dataset_schema_business_language")
    end

    data_test "errors on invalid email: #{email}", %{conn: conn} do
      assert_error_message(
        conn,
        TDG.create_dataset(%{business: %{contactEmail: email}}),
        :contactEmail,
        "Email is invalid."
      )

      where([
        [:email],
        ["foomail.com"],
        ["kevinspace@"],
        ["kevinspace@notarealdomain"],
        ["my little address"]
      ])
    end

    data_test "does not error on valid email: #{email}", %{conn: conn} do
      # Assert error message is blank (no error)
      assert_error_message(
        conn,
        TDG.create_dataset(%{business: %{contactEmail: email}}),
        :contactEmail,
        ""
      )

      where([
        [:email],
        ["foo@mail.com"],
        ["kevin@space.org"],
        ["my@little.gov"]
      ])
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

    test "should not add additional commas to keywords", %{conn: conn} do
      dataset = TDG.create_dataset(%{})
      DatasetCache.put(dataset)

      dataset_map =
        dataset
        |> dataset_to_map()
        |> put_in([:business, :keywords], dataset.business.keywords |> Enum.join(", "))

      expected = Enum.join(dataset.business.keywords, ", ")

      assert {:ok, view, _html} = live(conn, @url_path <> dataset.id)
      html = render_change(view, :validate, %{"dataset_schema" => dataset_map})

      subject = get_value(html, "#dataset_schema_business_keywords")

      assert expected == subject
    end

    test "should trim spaces in keywords", %{conn: conn} do
      dataset = TDG.create_dataset(%{})
      DatasetCache.put(dataset)

      dataset_map =
        dataset
        |> dataset_to_map
        |> put_in([:business, :keywords], "a , good ,  keyword   , is .... hard , to find")

      assert {:ok, view, _html} = live(conn, @url_path <> dataset.id)
      html = render_change(view, :validate, %{"dataset_schema" => dataset_map})

      subject = get_value(html, "#dataset_schema_business_keywords")

      assert "a, good, keyword, is .... hard, to find" == subject
    end

    test "can handle lists of keywords", %{conn: conn} do
      dataset = TDG.create_dataset(%{})
      DatasetCache.put(dataset)

      dataset_map =
        dataset
        |> dataset_to_map()
        |> put_in([:business, :keywords], dataset.business.keywords)

      expected = Enum.join(dataset.business.keywords, ", ")

      assert {:ok, view, _html} = live(conn, @url_path <> dataset.id)
      html = render_change(view, :validate, %{"dataset_schema" => dataset_map})

      subject = get_value(html, "#dataset_schema_business_keywords")

      assert expected == subject
    end

    test "displays all other fields", %{conn: conn} do
      dataset =
        TDG.create_dataset(%{
          business: %{description: "A description with no special characters"},
          technical: %{private: true}
        })

      DatasetCache.put(dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)
      assert get_value(html, "#dataset_schema_business_dataTitle") == dataset.business.dataTitle
      assert get_text(html, "#dataset_schema_business_description") == dataset.business.description
      assert get_value(html, "#dataset_schema_technical_sourceFormat") == dataset.technical.sourceFormat
      assert {"true", "Private"} = get_select(html, "#dataset_schema_technical_private")
      assert get_value(html, "#dataset_schema_business_contactName") == dataset.business.contactName
      assert get_value(html, "#dataset_schema_business_contactEmail") == dataset.business.contactEmail
      assert get_value(html, "#dataset_schema_business_release-date") == dataset.business.issuedDate
      assert get_value(html, "#dataset_schema_business_license") == dataset.business.license
      assert get_value(html, "#dataset_schema_business_update-frequency") == dataset.business.publishFrequency
      assert get_value(html, "#dataset_schema_business_modifiedDate") == dataset.business.modifiedDate
      assert get_value(html, "#dataset_schema_business_spatial") == dataset.business.spatial
      assert get_value(html, "#dataset_schema_business_temporal") == dataset.business.temporal
      assert get_value(html, "#dataset_schema_business_orgTitle") == dataset.business.orgTitle
      assert {"english", "English"} = get_select(html, "#dataset_schema_business_language")
      assert get_value(html, "#dataset_schema_business_homepage") == dataset.business.homepage
    end
  end

  describe "edit metadata" do
    test "accessibility level must be public or private", %{conn: conn} do
      dataset = TDG.create_dataset(%{technical: %{private: true}})

      DatasetCache.put(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      assert get_select(html, "#dataset_schema_technical_private") == {"true", "Private"}

      dataset_map = dataset_to_map(dataset) |> put_in([:technical, :private], false)

      html = render_change(view, :validate, %{"dataset_schema" => dataset_map})
      assert get_select(html, "#dataset_schema_technical_private") == {"false", "Public"}
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

  describe "can not edit" do
    test "source format", %{conn: conn} do
      dataset = TDG.create_dataset(%{})

      DatasetCache.put(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert Floki.attribute(html, "#dataset_schema_technical_sourceFormat", "readonly") == ["readonly"]
    end

    test "organization title", %{conn: conn} do
      dataset = TDG.create_dataset(%{})

      DatasetCache.put(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert Floki.attribute(html, "#dataset_schema_business_orgTitle", "readonly") == ["readonly"]
    end
  end

  describe "save metadata" do
    test "valid metadata is saved on submit", %{conn: conn} do
      dataset =
        TDG.create_dataset(%{
          business: %{issuedDate: "", publishFrequency: "12345"},
          technical: %{cadence: "123"}
        })

      DatasetCache.put(dataset)
      allow(Brook.Event.send(any(), any(), :andi, any()), return: :ok)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      dataset_map =
        dataset_to_map(dataset)
        |> put_in([:business, :issuedDate], "12345")

      render_change(view, :save, %{"dataset_schema" => dataset_map})

      dataset_map = dataset_map |> put_in([:technical, :schema], dataset.technical.schema)

      {:ok, updated_dataset} = SmartCity.Dataset.new(dataset_map)

      assert_called(Brook.Event.send(instance_name(), dataset_update(), :andi, updated_dataset), once())
    end

    test "invalid metadata is not saved on submit", %{conn: conn} do
      dataset = TDG.create_dataset(%{business: %{publishFrequency: ""}})
      DatasetCache.put(dataset)

      dataset_map = dataset_to_map(dataset)

      allow(Brook.Event.send(any(), any(), :andi, any()), return: :ok)

      assert {:ok, view, _html} = live(conn, @url_path <> dataset.id)
      render_change(view, :save, %{"dataset_schema" => dataset_map})

      refute_called(Brook.Event.send(instance_name(), dataset_update(), :andi, dataset), once())
    end

    test "success message is displayed when metadata is saved", %{conn: conn} do
      dataset =
        TDG.create_dataset(%{
          business: %{issuedDate: "", publishFrequency: "12345"},
          technical: %{cadence: "123"}
        })

      DatasetCache.put(dataset)
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert get_text(html, "#success-message") == ""

      dataset_map = dataset_to_map(dataset) |> put_in([:business, :issuedDate], "12345")

      render_change(view, :validate, %{"dataset_schema" => dataset_map})
      html = render_change(view, :save, %{"dataset_schema" => dataset_map})

      assert get_text(html, "#success-message") == "Saved Successfully"
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

  defp get_select(html, id) do
    {_, [{_, value} | _], [text]} =
      Floki.find(html, id)
      |> Floki.find("select option")
      |> Enum.filter(fn {_, list, _} -> list |> Enum.any?(&(&1 == {"selected", "selected"})) end)
      |> List.first()

    {value, text}
  end

  defp dataset_to_map(dataset) do
    map_tech = dataset.technical |> Map.from_struct() |> Map.delete(:schema)

    map_bus =
      dataset.business
      |> Map.from_struct()

    dataset
    |> Map.from_struct()
    |> Map.put(:business, map_bus)
    |> Map.put(:technical, map_tech)
  end
end
