defmodule AndiWeb.EditLiveViewTest do
  use AndiWeb.ConnCase
  use Phoenix.ConnTest
  use Placebo

  import Phoenix.LiveViewTest
  import Checkov
  import Andi
  import SmartCity.Event, only: [dataset_update: 0]

  alias Andi.DatasetCache
  alias Andi.InputSchemas.InputConverter

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
      assert {"false", "Public"} = get_select(html, "#metadata_private")
    end

    test "display Level of Access as private when private is true", %{conn: conn} do
      dataset = TDG.create_dataset(%{technical: %{private: true}})
      DatasetCache.put(dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)
      assert {"true", "Private"} = get_select(html, "#metadata_private")
    end

    test "the default language is set to english", %{conn: conn} do
      dataset = TDG.create_dataset(%{business: %{language: nil}})
      DatasetCache.put(dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)

      assert {"english", "English"} = get_select(html, "#metadata_language")
    end

    test "the language is set to spanish", %{conn: conn} do
      dataset = TDG.create_dataset(%{business: %{language: "spanish"}})
      DatasetCache.put(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert {"spanish", "Spanish"} = get_select(html, "#metadata_language")
    end

    test "the language is set to english", %{conn: conn} do
      dataset = TDG.create_dataset(%{business: %{language: "english"}})
      DatasetCache.put(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert {"english", "English"} = get_select(html, "#metadata_language")
    end

    test "the language is changed from english to spanish", %{conn: conn} do
      dataset = TDG.create_dataset(%{business: %{language: "english"}})
      DatasetCache.put(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      dataset_map = dataset_to_map(dataset) |> Map.put(:language, "spanish")

      html = render_change(view, :validate, %{"metadata" => dataset_map})

      assert {"spanish", "Spanish"} = get_select(html, "#metadata_language")
    end

    data_test "errors on invalid email: #{email}", %{conn: conn} do
      assert_error_message(
        conn,
        TDG.create_dataset(%{business: %{contactEmail: email}}),
        :contactEmail,
        "Please enter a valid maintainer email."
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
      [subject] = Floki.find(html, "#metadata_keywords") |> Floki.attribute("value")

      assert subject =~ "one, two, three"
    end

    test "keywords input should show empty string if keywords is nil", %{conn: conn} do
      dataset = TDG.create_dataset(%{business: %{keywords: nil}})
      DatasetCache.put(dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)
      [subject] = Floki.find(html, "#metadata_keywords") |> Floki.attribute("value")

      assert subject == ""
    end

    test "should not add additional commas to keywords", %{conn: conn} do
      dataset = TDG.create_dataset(%{})
      DatasetCache.put(dataset)

      dataset_map =
        dataset
        |> dataset_to_map()
        |> Map.put(:keywords, Enum.join(dataset.business.keywords, ", "))

      expected = Enum.join(dataset.business.keywords, ", ")

      assert {:ok, view, _html} = live(conn, @url_path <> dataset.id)
      html = render_change(view, :validate, %{"metadata" => dataset_map})

      subject = get_value(html, "#metadata_keywords")

      assert expected == subject
    end

    test "should trim spaces in keywords", %{conn: conn} do
      dataset = TDG.create_dataset(%{})
      DatasetCache.put(dataset)

      dataset_map =
        dataset
        |> dataset_to_map()
        |> Map.put(:keywords, "a , good ,  keyword   , is .... hard , to find")

      assert {:ok, view, _html} = live(conn, @url_path <> dataset.id)
      html = render_change(view, :validate, %{"metadata" => dataset_map})

      subject = get_value(html, "#metadata_keywords")

      assert "a, good, keyword, is .... hard, to find" == subject
    end

    test "can handle lists of keywords", %{conn: conn} do
      dataset = TDG.create_dataset(%{})
      DatasetCache.put(dataset)
      expected = Enum.join(dataset.business.keywords, ", ")

      dataset_map =
        dataset
        |> dataset_to_map()
        |> Map.put(:keywords, expected)

      assert {:ok, view, _html} = live(conn, @url_path <> dataset.id)
      html = render_change(view, :validate, %{"metadata" => dataset_map})

      subject = get_value(html, "#metadata_keywords")

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
      assert get_value(html, "#metadata_dataTitle") == dataset.business.dataTitle
      assert get_text(html, "#metadata_description") == dataset.business.description
      assert get_value(html, "#metadata_sourceFormat") == dataset.technical.sourceFormat
      assert {"true", "Private"} == get_select(html, "#metadata_private")
      assert get_value(html, "#metadata_contactName") == dataset.business.contactName
      assert dataset.business.modifiedDate =~ get_value(html, "#metadata_modifiedDate")
      assert get_value(html, "#metadata_contactEmail") == dataset.business.contactEmail
      assert dataset.business.issuedDate =~ get_value(html, "#metadata_issuedDate")
      assert get_value(html, "#metadata_license") == dataset.business.license
      assert get_value(html, "#metadata_publishFrequency") == dataset.business.publishFrequency
      assert get_value(html, "#metadata_spatial") == dataset.business.spatial
      assert get_value(html, "#metadata_temporal") == dataset.business.temporal
      assert get_value(html, "#metadata_orgTitle") == dataset.business.orgTitle
      assert {"english", "English"} == get_select(html, "#metadata_language")
      assert get_value(html, "#metadata_homepage") == dataset.business.homepage
    end
  end

  describe "edit metadata" do
    test "accessibility level must be public or private", %{conn: conn} do
      dataset = TDG.create_dataset(%{technical: %{private: true}})

      DatasetCache.put(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      assert get_select(html, "#metadata_private") == {"true", "Private"}

      dataset_map = dataset_to_map(dataset) |> Map.put(:private, false)

      html = render_change(view, :validate, %{"metadata" => dataset_map})
      assert get_select(html, "#metadata_private") == {"false", "Public"}
    end

    test "All required fields display proper error message", %{conn: conn} do
      assert_error_message(
        conn,
        TDG.create_dataset(%{business: %{dataTitle: ""}}),
        :dataTitle,
        "Please enter a valid dataset title."
      )

      assert_error_message(
        conn,
        TDG.create_dataset(%{business: %{description: ""}}),
        :description,
        "Please enter a valid description."
      )

      assert_error_message(
        conn,
        TDG.create_dataset(%{business: %{contactName: ""}}),
        :contactName,
        "Please enter a valid maintainer name."
      )

      assert_error_message(
        conn,
        TDG.create_dataset(%{business: %{contactEmail: ""}}),
        :contactEmail,
        "Please enter a valid maintainer email."
      )

      assert_error_message(
        conn,
        TDG.create_dataset(%{business: %{issuedDate: ""}}),
        :issuedDate,
        "Please enter a valid release date."
      )

      assert_error_message(
        conn,
        TDG.create_dataset(%{business: %{license: ""}}),
        :license,
        "Please enter a valid license."
      )

      dataset = TDG.create_dataset(%{})
      new_tech = Map.put(dataset.technical, :sourceFormat, "")
      dataset = Map.put(dataset, :technical, new_tech)

      assert_error_message(
        conn,
        dataset,
        :sourceFormat,
        "Please enter a valid source format."
      )

      assert_error_message(
        conn,
        TDG.create_dataset(%{business: %{publishFrequency: ""}}),
        :publishFrequency,
        "Please enter a valid update frequency."
      )

      assert_error_message(
        conn,
        TDG.create_dataset(%{business: %{orgTitle: ""}}),
        :orgTitle,
        "Please enter a valid organization."
      )
    end

    test "error message is cleared when form is updated", %{conn: conn} do
      dataset = TDG.create_dataset(%{business: %{issuedDate: ""}})
      DatasetCache.put(dataset)

      form_data =
        dataset
        |> InputConverter.changeset_from_dataset()
        |> form_data_for_save()

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      render_change(view, :save, %{"metadata" => form_data})

      assert render(view) |> get_text(".metadata__error-message") =~ "errors"

      form_data =
        dataset
        |> InputConverter.changeset_from_dataset()
        |> Ecto.Changeset.cast(%{issuedDate: "2020-01-03"}, [:issuedDate])
        |> form_data_for_save()

      render_change(view, :validate, %{"metadata" => form_data})

      assert render(view) |> get_text(".metadata__error-message") == ""
    end
  end

  describe "can not edit" do
    test "source format", %{conn: conn} do
      dataset = TDG.create_dataset(%{})

      DatasetCache.put(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert Floki.attribute(html, "#metadata_sourceFormat", "readonly") == ["readonly"]
    end

    test "organization title", %{conn: conn} do
      dataset = TDG.create_dataset(%{})

      DatasetCache.put(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert Floki.attribute(html, "#metadata_orgTitle", "readonly") == ["readonly"]
    end
  end

  describe "save metadata" do
    test "valid metadata is saved on submit", %{conn: conn} do
      allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)

      dataset =
        TDG.create_dataset(%{
          business: %{issuedDate: "", publishFrequency: "12345"},
          technical: %{cadence: "123"}
        })

      DatasetCache.put(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data =
        dataset
        |> InputConverter.changeset_from_dataset()
        |> Ecto.Changeset.cast(%{issuedDate: "2020-01-03"}, [:issuedDate])
        |> form_data_for_save()

      render_change(view, :save, %{"metadata" => form_data})

      updated_dataset =
        form_data
        |> InputConverter.form_changeset()
        |> Ecto.Changeset.apply_changes()
        |> InputConverter.restruct(dataset)

      assert_called(Brook.Event.send(instance_name(), dataset_update(), :andi, updated_dataset), once())
    end

    test "invalid metadata is not saved on submit", %{conn: conn} do
      dataset = TDG.create_dataset(%{business: %{publishFrequency: ""}})
      DatasetCache.put(dataset)

      dataset_map = dataset_to_map(dataset)

      allow(Brook.Event.send(any(), any(), :andi, any()), return: :ok)

      assert {:ok, view, _html} = live(conn, @url_path <> dataset.id)
      render_change(view, :save, %{"metadata" => dataset_map})

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

      form_data =
        dataset
        |> InputConverter.changeset_from_dataset()
        |> Ecto.Changeset.cast(%{issuedDate: "2020-01-03"}, [:issuedDate])
        |> form_data_for_save()

      render_change(view, :validate, %{"metadata" => form_data})
      html = render_change(view, :save, %{"metadata" => form_data})

      assert get_text(html, "#success-message") == "Saved Successfully"
    end

    test "allows clearing modified date", %{conn: conn} do
      allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)

      dataset =
        TDG.create_dataset(%{
          business: %{modifiedDate: "2020-01-01"}
        })

      DatasetCache.put(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data =
        dataset
        |> InputConverter.changeset_from_dataset()
        |> Ecto.Changeset.cast(%{modifiedDate: nil}, [:modifiedDate], empty_values: [])
        |> form_data_for_save()

      render_change(view, :save, %{"metadata" => form_data})

      expected_updated_dataset =
        form_data
        |> InputConverter.form_changeset()
        |> Ecto.Changeset.apply_changes()
        |> InputConverter.restruct(dataset)

      assert_called(Brook.Event.send(instance_name(), dataset_update(), :andi, expected_updated_dataset), once())
    end

    test "does not save when dataset org and data name match existing dataset", %{conn: conn} do
      allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)

      dataset = TDG.create_dataset(%{business: %{issuedDate: nil}})
      DatasetCache.put(dataset)

      existing_dataset = TDG.create_dataset(%{technical: %{dataName: dataset.technical.dataName, orgName: dataset.technical.orgName}})
      DatasetCache.put(existing_dataset)

      form_data =
        dataset
        |> InputConverter.changeset_from_dataset()
        |> Ecto.Changeset.cast(%{issuedDate: "2020-01-03"}, [:issuedDate])
        |> form_data_for_save()

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      render_change(view, :save, %{"metadata" => form_data})

      refute_called(Brook.Event.send(any(), any(), any(), any()))

      assert render(view) |> get_text(".metadata__error-message") =~ "errors"
    end
  end

  defp assert_error_message(conn, dataset, field, error_message) do
    DatasetCache.put(dataset)

    form_data =
      dataset
      |> InputConverter.changeset_from_dataset()
      |> form_data_for_save()

    assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
    html = render_change(view, :save, %{"metadata" => form_data})

    assert get_text(html, "##{field}-error-msg") == error_message
  end

  defp form_data_for_save(changeset) do
    changeset
    |> Ecto.Changeset.apply_changes()
    |> Map.update!(:keywords, &Enum.join(&1, ", "))
    |> Map.delete(:schema)

    # For now, schema needs to be removed from the form data as it cannot be encoded in the form as an array of maps.
    # Once we start editing the schema in the form, we will need to address this (probably by changing the schema structure in the form data).
  end

  defp get_value(html, id) do
    Floki.find(html, id) |> Floki.attribute("value") |> List.first()
  end

  defp get_text(html, id) do
    Floki.find(html, id)
    |> Floki.text()
    |> String.trim()
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

    map_bus = Map.from_struct(dataset.business)

    dataset
    |> Map.from_struct()
    |> Map.put(:business, map_bus)
    |> Map.put(:technical, map_tech)
  end
end
