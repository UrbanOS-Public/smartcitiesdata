defmodule AndiWeb.EditLiveViewTest do
  use AndiWeb.ConnCase
  use Phoenix.ConnTest
  use Placebo

  import Phoenix.LiveViewTest
  import Checkov
  import Andi
  import SmartCity.Event, only: [dataset_update: 0]
  import SmartCity.TestHelper

  alias Andi.DatasetCache
  alias Andi.InputSchemas.InputConverter
  alias Andi.Services.UrlTest

  import FlokiHelpers,
    only: [
      get_attributes: 3,
      get_select: 2,
      get_text: 2,
      get_value: 2,
      get_values: 2,
      find_elements: 2
    ]

  alias SmartCity.TestDataGenerator, as: TDG

  @url_path "/datasets/"

  setup do
    GenServer.call(DatasetCache, :reset)
  end

  describe "enter form data" do
    test "display Level of Access as public when private is false", %{conn: conn} do
      dataset = TDG.create_dataset(%{technical: %{private: false}})
      DatasetCache.put(dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)
      assert {"false", "Public"} = get_select(html, "#form_data_private")
    end

    test "display Level of Access as private when private is true", %{conn: conn} do
      dataset = TDG.create_dataset(%{technical: %{private: true}})
      DatasetCache.put(dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)
      assert {"true", "Private"} = get_select(html, "#form_data_private")
    end

    test "the default language is set to english", %{conn: conn} do
      dataset = TDG.create_dataset(%{business: %{language: nil}})
      DatasetCache.put(dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)

      assert {"english", "English"} = get_select(html, "#form_data_language")
    end

    test "the language is set to spanish", %{conn: conn} do
      dataset = TDG.create_dataset(%{business: %{language: "spanish"}})
      DatasetCache.put(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert {"spanish", "Spanish"} = get_select(html, "#form_data_language")
    end

    test "the language is set to english", %{conn: conn} do
      dataset = TDG.create_dataset(%{business: %{language: "english"}})
      DatasetCache.put(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert {"english", "English"} = get_select(html, "#form_data_language")
    end

    test "the language is changed from english to spanish", %{conn: conn} do
      dataset = TDG.create_dataset(%{business: %{language: "english"}})
      DatasetCache.put(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      dataset_map = dataset_to_form_data(dataset) |> Map.put(:language, "spanish")

      html = render_change(view, :validate, %{"form_data" => dataset_map})

      assert {"spanish", "Spanish"} = get_select(html, "#form_data_language")
    end

    data_test "benefit rating is set to '#{label}' (#{inspect(value)})", %{conn: conn} do
      dataset = TDG.create_dataset(%{business: %{benefitRating: value}})
      DatasetCache.put(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert {to_string(value), label} == get_select(html, "#form_data_benefitRating")

      where([
        [:value, :label],
        [0.0, "Low"],
        [0.5, "Medium"],
        [1.0, "High"]
      ])
    end

    data_test "risk rating is set to '#{label}' (#{inspect(value)})", %{conn: conn} do
      dataset = TDG.create_dataset(%{business: %{riskRating: value}})
      DatasetCache.put(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert {to_string(value), label} == get_select(html, "#form_data_riskRating")

      where([
        [:value, :label],
        [0.0, "Low"],
        [0.5, "Medium"],
        [1.0, "High"]
      ])
    end

    data_test "errors on invalid email: #{email}", %{conn: conn} do
      html = save_form_for_dataset(conn, TDG.create_dataset(%{business: %{contactEmail: email}}))

      assert get_text(html, "#contactEmail-error-msg") == "Please enter a valid maintainer email."

      where([
        [:email],
        ["foomail.com"],
        ["kevinspace@"],
        ["kevinspace@notarealdomain"],
        ["my little address"]
      ])
    end

    data_test "does not error on valid email: #{email}", %{conn: conn} do
      html = save_form_for_dataset(conn, TDG.create_dataset(%{business: %{contactEmail: email}}))

      assert get_text(html, "#contactEmail-error-msg") == ""

      where([
        [:email],
        ["foo@mail.com"],
        ["kevin@space.org"],
        ["my@little.gov"],
        ["test-email@email.com"]
      ])
    end

    test "adds commas between keywords", %{conn: conn} do
      dataset = TDG.create_dataset(%{business: %{keywords: ["one", "two", "three"]}})
      DatasetCache.put(dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)
      [subject] = get_values(html, "#form_data_keywords")

      assert subject =~ "one, two, three"
    end

    test "keywords input should show empty string if keywords is nil", %{conn: conn} do
      dataset = TDG.create_dataset(%{business: %{keywords: nil}})
      DatasetCache.put(dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)
      [subject] = get_values(html, "#form_data_keywords")

      assert subject == ""
    end

    test "should not add additional commas to keywords", %{conn: conn} do
      dataset = TDG.create_dataset(%{})
      DatasetCache.put(dataset)

      dataset_map =
        dataset
        |> dataset_to_form_data()
        |> Map.put(:keywords, Enum.join(dataset.business.keywords, ", "))

      expected = Enum.join(dataset.business.keywords, ", ")

      assert {:ok, view, _html} = live(conn, @url_path <> dataset.id)
      html = render_change(view, :validate, %{"form_data" => dataset_map})

      subject = get_value(html, "#form_data_keywords")

      assert expected == subject
    end

    test "should trim spaces in keywords", %{conn: conn} do
      dataset = TDG.create_dataset(%{})
      DatasetCache.put(dataset)

      dataset_map =
        dataset
        |> dataset_to_form_data()
        |> Map.put(:keywords, "a , good ,  keyword   , is .... hard , to find")

      assert {:ok, view, _html} = live(conn, @url_path <> dataset.id)
      html = render_change(view, :validate, %{"form_data" => dataset_map})

      subject = get_value(html, "#form_data_keywords")

      assert "a, good, keyword, is .... hard, to find" == subject
    end

    test "can handle lists of keywords", %{conn: conn} do
      dataset = TDG.create_dataset(%{})
      DatasetCache.put(dataset)
      expected = Enum.join(dataset.business.keywords, ", ")

      dataset_map =
        dataset
        |> dataset_to_form_data()
        |> Map.put(:keywords, expected)

      assert {:ok, view, _html} = live(conn, @url_path <> dataset.id)
      html = render_change(view, :validate, %{"form_data" => dataset_map})

      subject = get_value(html, "#form_data_keywords")

      assert expected == subject
    end

    test "displays all other fields", %{conn: conn} do
      dataset =
        TDG.create_dataset(%{
          business: %{description: "A description with no special characters", benefitRating: 1.0, riskRating: 0.5},
          technical: %{private: true}
        })

      DatasetCache.put(dataset)

      assert {:ok, _view, html} = live(conn, @url_path <> dataset.id)
      assert get_value(html, "#form_data_dataTitle") == dataset.business.dataTitle
      assert get_text(html, "#form_data_description") == dataset.business.description
      assert get_value(html, "#form_data_sourceFormat") == dataset.technical.sourceFormat
      assert {"true", "Private"} == get_select(html, "#form_data_private")
      assert get_value(html, "#form_data_contactName") == dataset.business.contactName
      assert dataset.business.modifiedDate =~ get_value(html, "#form_data_modifiedDate")
      assert get_value(html, "#form_data_contactEmail") == dataset.business.contactEmail
      assert dataset.business.issuedDate =~ get_value(html, "#form_data_issuedDate")
      assert get_value(html, "#form_data_license") == dataset.business.license
      assert get_value(html, "#form_data_publishFrequency") == dataset.business.publishFrequency
      assert get_value(html, "#form_data_spatial") == dataset.business.spatial
      assert get_value(html, "#form_data_temporal") == dataset.business.temporal
      assert get_value(html, "#form_data_orgTitle") == dataset.business.orgTitle
      assert {"english", "English"} == get_select(html, "#form_data_language")
      assert get_value(html, "#form_data_homepage") == dataset.business.homepage
      assert {"1.0", "High"} == get_select(html, "#form_data_benefitRating")
      assert {"0.5", "Medium"} == get_select(html, "#form_data_riskRating")
    end
  end

  describe "edit form data" do
    test "accessibility level must be public or private", %{conn: conn} do
      dataset = TDG.create_dataset(%{technical: %{private: true}})

      DatasetCache.put(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      assert get_select(html, "#form_data_private") == {"true", "Private"}

      dataset_map = dataset_to_form_data(dataset) |> Map.put(:private, false)

      html = render_change(view, :validate, %{"form_data" => dataset_map})
      assert get_select(html, "#form_data_private") == {"false", "Public"}
    end

    data_test "required #{field} field displays proper error message", %{conn: conn} do
      html = save_form_for_dataset(conn, TDG.create_dataset(dataset_override))

      assert get_text(html, "##{field}-error-msg") == expected_error_message

      where([
        [:field, :dataset_override, :expected_error_message],
        [:dataTitle, %{business: %{dataTitle: ""}}, "Please enter a valid dataset title."],
        [:description, %{business: %{description: ""}}, "Please enter a valid description."],
        [:contactName, %{business: %{contactName: ""}}, "Please enter a valid maintainer name."],
        [:contactEmail, %{business: %{contactEmail: ""}}, "Please enter a valid maintainer email."],
        [:issuedDate, %{business: %{issuedDate: ""}}, "Please enter a valid release date."],
        [:license, %{business: %{license: ""}}, "Please enter a valid license."],
        [:publishFrequency, %{business: %{publishFrequency: ""}}, "Please enter a valid update frequency."],
        [:orgTitle, %{business: %{orgTitle: ""}}, "Please enter a valid organization."],
        [:sourceUrl, %{technical: %{sourceUrl: ""}}, "Please enter a valid base url."],
        [:license, %{business: %{license: ""}}, "Please enter a valid license."],
        [:benefitRating, %{business: %{benefitRating: ""}}, "Please enter a valid benefit."],
        [:riskRating, %{business: %{riskRating: ""}}, "Please enter a valid risk."]
      ])
    end

    test "required sourceFormat displays proper error message", %{conn: conn} do
      dataset = TDG.create_dataset(%{})
      new_tech = Map.put(dataset.technical, :sourceFormat, "")
      dataset = Map.put(dataset, :technical, new_tech)

      html = save_form_for_dataset(conn, dataset)

      assert get_text(html, "#sourceFormat-error-msg") == "Please enter a valid source format."
    end

    data_test "invalid #{field} displays proper error message", %{conn: conn} do
      dataset = TDG.create_dataset(%{technical: %{field => %{"foo" => "where's my key"}}})
      DatasetCache.put(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data = dataset_to_form_data(dataset) |> Map.put(field, %{"0" => %{"key" => "", "value" => "where's my key"}})
      render_change(view, :validate, %{"form_data" => form_data})
      html = render(view)

      assert get_text(html, "##{field}-error-msg") == "Please enter valid key(s)."

      where(field: [:sourceQueryParams, :sourceHeaders])
    end

    data_test "displays error when #{field} is unset", %{conn: conn} do
      dataset = TDG.create_dataset(%{})
      DatasetCache.put(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      assert get_text(html, "##{field}-error-msg") == ""

      form_data = dataset_to_form_data(dataset) |> Map.put(field, "")
      html = render_change(view, :validate, %{"form_data" => form_data})

      assert get_text(html, "##{field}-error-msg") == expected_error_message

      where([
        [:field, :expected_error_message],
        [:benefitRating, "Please enter a valid benefit."],
        [:riskRating, "Please enter a valid risk."]
      ])
    end

    test "error message is cleared when form is updated", %{conn: conn} do
      dataset = TDG.create_dataset(%{business: %{issuedDate: ""}})
      DatasetCache.put(dataset)

      form_data =
        dataset
        |> InputConverter.changeset_from_dataset()
        |> form_data_for_save()

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      render_change(view, :save, %{"form_data" => form_data})

      assert render(view) |> get_text(".metadata__error-message") =~ "errors"

      form_data =
        dataset
        |> InputConverter.changeset_from_dataset()
        |> Ecto.Changeset.cast(%{issuedDate: "2020-01-03"}, [:issuedDate])
        |> form_data_for_save()

      render_change(view, :validate, %{"form_data" => form_data})

      assert render(view) |> get_text(".metadata__error-message") == ""
    end
  end

  describe "can not edit" do
    test "source format", %{conn: conn} do
      dataset = TDG.create_dataset(%{})

      DatasetCache.put(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert get_attributes(html, "#form_data_sourceFormat", "readonly") == ["readonly"]
    end

    test "organization title", %{conn: conn} do
      dataset = TDG.create_dataset(%{})

      DatasetCache.put(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert get_attributes(html, "#form_data_orgTitle", "readonly") == ["readonly"]
    end
  end

  describe "save form data" do
    test "valid form data is saved on submit", %{conn: conn} do
      allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)

      dataset = TDG.create_dataset(%{business: %{issuedDate: ""}})

      DatasetCache.put(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data =
        dataset
        |> InputConverter.changeset_from_dataset()
        |> Ecto.Changeset.cast(%{issuedDate: "2020-01-03"}, [:issuedDate])
        |> form_data_for_save()

      render_change(view, :save, %{"form_data" => form_data})

      updated_dataset =
        form_data
        |> InputConverter.form_changeset()
        |> Ecto.Changeset.apply_changes()
        |> InputConverter.restruct(dataset)

      assert_called(Brook.Event.send(instance_name(), dataset_update(), :andi, updated_dataset), once())
    end

    test "invalid form data is not saved on submit", %{conn: conn} do
      dataset = TDG.create_dataset(%{business: %{publishFrequency: ""}})
      DatasetCache.put(dataset)

      dataset_map = dataset_to_form_data(dataset)

      allow(Brook.Event.send(any(), any(), :andi, any()), return: :ok)

      assert {:ok, view, _html} = live(conn, @url_path <> dataset.id)
      render_change(view, :save, %{"form_data" => dataset_map})

      refute_called(Brook.Event.send(instance_name(), dataset_update(), :andi, dataset), once())
    end

    test "success message is displayed when form data is saved", %{conn: conn} do
      dataset = TDG.create_dataset(%{business: %{issuedDate: ""}})

      DatasetCache.put(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      assert get_text(html, "#success-message") == ""

      form_data =
        dataset
        |> InputConverter.changeset_from_dataset()
        |> Ecto.Changeset.cast(%{issuedDate: "2020-01-03"}, [:issuedDate])
        |> form_data_for_save()

      render_change(view, :validate, %{"form_data" => form_data})
      html = render_change(view, :save, %{"form_data" => form_data})

      assert get_text(html, "#success-message") == "Saved Successfully"
    end

    test "allows clearing modified date", %{conn: conn} do
      allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)

      dataset = TDG.create_dataset(%{business: %{modifiedDate: "2020-01-01"}})

      DatasetCache.put(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      form_data =
        dataset
        |> InputConverter.changeset_from_dataset()
        |> Ecto.Changeset.cast(%{modifiedDate: nil}, [:modifiedDate], empty_values: [])
        |> form_data_for_save()

      render_change(view, :save, %{"form_data" => form_data})

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
      render_change(view, :save, %{"form_data" => form_data})

      refute_called(Brook.Event.send(any(), any(), any(), any()))

      assert render(view) |> get_text(".metadata__error-message") =~ "errors"
    end

    data_test "allows saving with empty #{field}", %{conn: conn} do
      allow(Brook.Event.send(any(), any(), any(), any()), return: :ok)

      dataset = TDG.create_dataset(%{technical: %{field => %{"x" => "y"}}})
      DatasetCache.put(dataset)

      form_data =
        dataset
        |> dataset_to_form_data()
        |> Map.delete(field)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      render_change(view, :save, %{"form_data" => form_data})

      expected_updated_dataset =
        form_data
        |> InputConverter.form_changeset()
        |> Ecto.Changeset.apply_changes()
        |> InputConverter.restruct(dataset)

      assert_called(Brook.Event.send(instance_name(), dataset_update(), :andi, expected_updated_dataset), once())

      where(field: [:sourceQueryParams, :sourceHeaders])
    end
  end

  describe "sourceUrl testing" do
    @tag capture_log: true
    test "uses provided query params and headers", %{conn: conn} do
      dataset =
        TDG.create_dataset(%{
          technical: %{
            sourceUrl: "123.com",
            sourceQueryParams: %{"x" => "y"},
            sourceHeaders: %{"api-key" => "to-my-heart"}
          }
        })

      DatasetCache.put(dataset)

      allow(UrlTest.test(any(), any()), return: %{time: 1_000, status: 200})

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      render_change(view, :test_url, %{})

      assert_called(UrlTest.test("123.com", query_params: [{"x", "y"}], headers: [{"api-key", "to-my-heart"}]))
    end

    data_test "sourceQueryParams are updated when query params are added to source url", %{conn: conn} do
      dataset = TDG.create_dataset(%{})

      DatasetCache.put(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      html =
        render_change(view, :validate, %{
          "form_data" => %{"sourceUrl" => sourceUrl},
          "_target" => ["form_data", "sourceUrl"]
        })

      assert get_values(html, ".url-form__source-query-params-key-input") == keys
      assert get_values(html, ".url-form__source-query-params-value-input") == values

      where([
        [:sourceUrl, :keys, :values],
        ["http://example.com?cat=dog", ["cat"], ["dog"]],
        ["http://example.com?cat=dog&foo=bar", ["cat", "foo"], ["dog", "bar"]],
        ["http://example.com?cat=dog&foo+biz=bar", ["cat", "foo biz"], ["dog", "bar"]],
        ["http://example.com?cat=", ["cat"], [""]],
        ["http://example.com?=dog", [""], ["dog"]]
      ])
    end

    data_test "sourceUrl is updated when query params are added", %{conn: conn} do
      dataset = TDG.create_dataset(%{})

      DatasetCache.put(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      render_change(
        view,
        "validate",
        %{
          "form_data" => %{
            "sourceUrl" => intialSourceUrl,
            "sourceQueryParams" => queryParams,
            "schema" => dummy_schema()
          },
          "_target" => ["form_data", "sourceQueryParams"]
        }
      )

      assert render(view) |> get_values("#form_data_sourceUrl") == [updatedSourceUrl]

      where([
        [:intialSourceUrl, :queryParams, :updatedSourceUrl],
        [
          "http://example.com",
          %{"0" => %{"key" => "dog", "value" => "car"}, "1" => %{"key" => "new", "value" => "thing"}},
          "http://example.com?dog=car&new=thing"
        ],
        ["http://example.com?dog=cat&fish=water", %{"0" => %{"key" => "dog", "value" => "cat"}}, "http://example.com?dog=cat"],
        ["http://example.com?dog=cat&fish=water", %{}, "http://example.com"],
        [
          "http://example.com?dog=cat",
          %{"0" => %{"key" => "some space", "value" => "thing=whoa"}},
          "http://example.com?some+space=thing%3Dwhoa"
        ]
      ])
    end

    test "status and time are displayed when source url is tested", %{conn: conn} do
      dataset =
        TDG.create_dataset(%{
          technical: %{sourceUrl: "123.com"}
        })

      DatasetCache.put(dataset)

      allow(UrlTest.test("123.com", any()), return: %{time: 1_000, status: 200})

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      assert get_text(html, ".test-status__code") == ""
      assert get_text(html, ".test-status__time") == ""

      render_change(view, :test_url, %{})

      eventually(fn ->
        html = render(view)
        assert get_text(html, ".test-status__code") == "200"
        assert get_text(html, ".test-status__time") == "1000"
      end)
    end

    test "status is displayed with an appropriate class when it is between 200 and 399", %{conn: conn} do
      dataset = TDG.create_dataset(%{})

      DatasetCache.put(dataset)

      allow(UrlTest.test(dataset.technical.sourceUrl, any()), return: %{time: 1_000, status: 200})

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      assert get_text(html, ".test-status__code--good") == ""

      render_change(view, :test_url, %{})

      eventually(fn ->
        html = render(view)
        assert get_text(html, ".test-status__code--good") == "200"
      end)
    end

    test "status is displayed with an appropriate class when it is not between 200 and 399", %{conn: conn} do
      dataset = TDG.create_dataset(%{})

      DatasetCache.put(dataset)

      allow(UrlTest.test(dataset.technical.sourceUrl, any()), return: %{time: 1_000, status: 400})

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      assert get_text(html, ".test-status__code--bad") == ""

      render_change(view, :test_url, %{})

      eventually(fn ->
        html = render(view)
        assert get_text(html, ".test-status__code--bad") == "400"
        assert get_text(html, ".test-status__code--good") != "400"
      end)
    end

    @tag capture_log: true
    test "status is displayed with an appropriate class when an internal page error occurred", %{conn: conn} do
      dataset = TDG.create_dataset(%{})

      DatasetCache.put(dataset)

      allow(UrlTest.test(dataset.technical.sourceUrl, any()), exec: fn _ -> raise "derp" end)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      assert get_text(html, "#page-error-message") == ""

      render_change(view, :test_url, %{})

      eventually(fn ->
        html = render(view)
        assert get_text(html, "#page-error-message") == "A page error occurred"
      end)
    end
  end

  describe "updating source params" do
    setup do
      dataset =
        TDG.create_dataset(%{
          technical: %{
            sourceQueryParams: %{foo: "bar", baz: "biz"},
            sourceHeaders: %{fool: "barl", bazl: "bizl"}
          }
        })

      DatasetCache.put(dataset)

      %{dataset: dataset}
    end

    data_test "new key/value inputs are added when add button is pressed for #{field}", %{conn: conn, dataset: dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      render_click(view, "add", %{"field" => Atom.to_string(field)})
      html = render(view)

      assert html |> find_elements(key_class) |> length() == 3
      assert html |> find_elements(value_class) |> length() == 3

      where(
        field: [:sourceQueryParams, :sourceHeaders],
        key_class: [".url-form__source-query-params-key-input", ".url-form__source-headers-key-input"],
        value_class: [".url-form__source-query-params-value-input", ".url-form__source-headers-value-input"]
      )
    end

    data_test "key/value inputs are deleted when delete button is pressed for #{field}", %{conn: conn, dataset: dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      btn_id = html |> get_attributes(btn_class, "phx-value-id") |> hd()

      render_click(view, "remove", %{"id" => btn_id, "field" => Atom.to_string(field)})
      html = render(view)

      [key_input] = html |> get_attributes(key_class, "class")
      refute btn_id =~ key_input

      [value_input] = html |> get_attributes(value_class, "class")
      refute btn_id =~ value_input

      where(
        field: [:sourceQueryParams, :sourceHeaders],
        btn_class: [".url-form__source-query-params-delete-btn", ".url-form__source-headers-delete-btn"],
        key_class: [".url-form__source-query-params-key-input", ".url-form__source-headers-key-input"],
        value_class: [".url-form__source-query-params-value-input", ".url-form__source-headers-value-input"]
      )
    end

    data_test "does not have key/value inputs when dataset has no source #{field}", %{conn: conn} do
      dataset = TDG.create_dataset(%{})
      DatasetCache.put(dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      assert html |> find_elements(key_class) |> Enum.empty?()
      assert html |> find_elements(value_class) |> Enum.empty?()

      where(
        field: [:sourceQueryParams, :sourceHeaders],
        key_class: [".url-form__source-query-params-key-input", ".url-form__source-headers-key-input"],
        value_class: [".url-form__source-query-params-value-input", ".url-form__source-headers-value-input"]
      )
    end

    test "source url is updated when source query params are removed", %{conn: conn, dataset: dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)

      get_attributes(html, ".url-form__source-query-params-delete-btn", "phx-value-id")
      |> Enum.each(fn btn_id ->
        render_click(view, "remove", %{
          "id" => btn_id,
          "field" => Atom.to_string(:sourceQueryParams)
        })
      end)

      assert render(view) |> get_values("#form_data_sourceUrl") == [dataset.technical.sourceUrl]
    end
  end

  defp save_form_for_dataset(conn, dataset) do
    DatasetCache.put(dataset)

    form_data = dataset_to_form_data(dataset)

    assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
    render_change(view, :save, %{"form_data" => form_data})
  end

  defp form_data_for_save(changeset) do
    changeset
    |> Ecto.Changeset.apply_changes()
    |> Map.update!(:keywords, &Enum.join(&1, ", "))
    # until we add the ability to edit the schema/dictionary, putting a fake one on there for validation
    |> Map.put(:schema, dummy_schema())
  end

  defp dummy_schema() do
    %{"0" => %{"name" => "ignored_name", "type" => "ignored_type"}}
  end

  defp dataset_to_form_data(dataset) do
    dataset
    |> InputConverter.changeset_from_dataset()
    |> form_data_for_save()
  end
end
