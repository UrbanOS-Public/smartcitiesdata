defmodule AndiWeb.UrlFormTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  use Placebo
  import Checkov

  alias Andi.Services.UrlTest
  alias AndiWeb.InputSchemas.UrlFormSchema

  @moduletag shared_data_connection: true

  import Phoenix.LiveViewTest
  import SmartCity.TestHelper, only: [eventually: 1]

  import FlokiHelpers,
    only: [
      get_attributes: 3,
      get_value: 2,
      get_values: 2,
      get_text: 2,
      find_elements: 2
    ]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Datasets
  alias AndiWeb.Helpers.FormTools
  alias Andi.InputSchemas.InputConverter

  @endpoint AndiWeb.Endpoint
  @url_path "/datasets/"

  describe "updating source params" do
    setup do
      dataset =
        TDG.create_dataset(%{
          technical: %{
            sourceQueryParams: %{foo: "bar", baz: "biz"},
            sourceHeaders: %{fool: "barl", bazl: "bizl"}
          }
        })

      {:ok, andi_dataset} = Datasets.update(dataset)

      [dataset: andi_dataset]
    end

    data_test "new key/value inputs are added when add button is pressed for #{field}", %{conn: conn, dataset: dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      url_form_view = find_live_child(view, "url_form_editor")

      assert html |> find_elements(key_class) |> length() == 2
      assert html |> find_elements(value_class) |> length() == 2

      html = render_click(url_form_view, "add", %{"field" => Atom.to_string(field)})

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
      url_form_view = find_live_child(view, "url_form_editor")

      assert html |> find_elements(key_class) |> length() == 2
      assert html |> find_elements(value_class) |> length() == 2

      btn_id =
        get_attributes(html, btn_class, "phx-value-id")
        |> hd()

      html = render_click(url_form_view, "remove", %{"id" => btn_id, "field" => Atom.to_string(field)})

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
      dataset = TDG.create_dataset(%{technical: %{field => %{}}})
      {:ok, _andi_dataset} = Datasets.update(dataset)

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
      url_form_view = find_live_child(view, "url_form_editor")

      assert html |> find_elements(".url-form__source-query-params-delete-btn") |> length() == 2

      get_attributes(html, ".url-form__source-query-params-delete-btn", "phx-value-id")
      |> Enum.each(fn btn_id ->
        render_click(url_form_view, "remove", %{
          "id" => btn_id,
          "field" => Atom.to_string(:sourceQueryParams)
        })
      end)

      url_with_no_query_params = Andi.URI.clear_query_params(dataset.technical.sourceUrl)

      assert render(url_form_view) |> get_values(".url-form__source-url input") == [url_with_no_query_params]
    end

    test "source query params added by source url updates can be removed", %{conn: conn, dataset: dataset} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      url_form_view = find_live_child(view, "url_form_editor")

      assert html |> find_elements(".url-form__source-query-params-delete-btn") |> length() == 2

      source_url_on_page = get_value(html, ".url-form__source-url input")
      updated_source_url = source_url_on_page <> "&knuckles=true"

      html =
        render_change(url_form_view, :validate, %{
          "form_data" => %{"id" => dataset.technical.id, "sourceUrl" => updated_source_url},
          "_target" => ["form_data", "sourceUrl"]
        })

      assert html |> find_elements(".url-form__source-query-params-delete-btn") |> length() == 3

      get_attributes(html, ".url-form__source-query-params-delete-btn", "phx-value-id")
      |> Enum.each(fn btn_id ->
        render_click(url_form_view, "remove", %{
          "id" => btn_id,
          "field" => Atom.to_string(:sourceQueryParams)
        })
      end)

      url_with_no_query_params = Andi.URI.clear_query_params(dataset.technical.sourceUrl)

      assert render(url_form_view) |> get_value(".url-form__source-url input") == url_with_no_query_params
    end
  end

  describe "sourceUrl testing" do
    @tag capture_log: true
    test "uses provided query params and headers", %{conn: conn} do
      smrt_dataset =
        TDG.create_dataset(%{
          technical: %{
            sourceUrl: "123.com",
            sourceQueryParams: %{"x" => "y"},
            sourceHeaders: %{"api-key" => "to-my-heart"}
          }
        })

      {:ok, dataset} = Datasets.update(smrt_dataset)

      allow(UrlTest.test(any(), any()), return: %{time: 1_000, status: 200})

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      url_form_view = find_live_child(view, "url_form_editor")
      render_change(url_form_view, :test_url, %{})

      assert_called(UrlTest.test("123.com", query_params: [{"x", "y"}], headers: [{"api-key", "to-my-heart"}]))
    end

    data_test "sourceQueryParams are updated when query params are added to source url", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      url_form_view = find_live_child(view, "url_form_editor")

      form_data = %{"sourceUrl" => sourceUrl}

      html =
        render_change(url_form_view, :validate, %{
          "form_data" => form_data,
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
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      url_form_view = find_live_child(view, "url_form_editor")

      form_data = %{"sourceQueryParams" => queryParams, "sourceUrl" => initialSourceUrl}

      html =
        render_change(url_form_view, :validate, %{
          "form_data" => form_data,
          "_target" => ["form_data", "sourceQueryParams"]
        })

      assert get_values(html, ".url-form__source-url input") == [updatedSourceUrl]

      where([
        [:initialSourceUrl, :queryParams, :updatedSourceUrl],
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
      smrt_dataset = TDG.create_dataset(%{technical: %{sourceUrl: "123.com"}})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      allow(UrlTest.test("123.com", any()), return: %{time: 1_000, status: 200})

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      url_form_view = find_live_child(view, "url_form_editor")

      assert get_text(html, ".test-status__code") == ""
      assert get_text(html, ".test-status__time") == ""

      render_change(url_form_view, :test_url, %{})

      eventually(fn ->
        html = render(url_form_view)
        assert get_text(html, ".test-status__code") == "Success"
        assert get_text(html, ".test-status__time") == "1000"
      end)
    end

    test "status is displayed with an appropriate class when it is between 200 and 399", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      allow(UrlTest.test(dataset.technical.sourceUrl, any()), return: %{time: 1_000, status: 200})

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      url_form_view = find_live_child(view, "url_form_editor")

      assert get_text(html, ".test-status__code--good") == ""

      render_change(url_form_view, :test_url, %{})

      eventually(fn ->
        html = render(url_form_view)
        assert get_text(html, ".test-status__code--good") == "Success"
      end)
    end

    test "status is displayed with an appropriate class when it is not between 200 and 399", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{})

      {:ok, dataset} = Datasets.update(smrt_dataset)

      allow(UrlTest.test(dataset.technical.sourceUrl, any()), return: %{time: 1_000, status: 400})

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      url_form_view = find_live_child(view, "url_form_editor")

      assert get_text(html, ".test-status__code--bad") == ""

      render_change(url_form_view, :test_url, %{})

      eventually(fn ->
        html = render(url_form_view)
        assert get_text(html, ".test-status__code--bad") == "Error"
        assert get_text(html, ".test-status__code--good") != "Error"
      end)
    end
  end

  test "required sourceUrl field displays proper error message", %{conn: conn} do
    smrt_dataset = TDG.create_dataset(%{})

    {:ok, dataset} =
      InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
      |> Datasets.save()

    assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
    url_form_view = find_live_child(view, "url_form_editor")

    form_data = %{"sourceUrl" => ""}

    html = render_change(url_form_view, :validate, %{"form_data" => form_data})

    assert get_text(html, "#sourceUrl-error-msg") == "Please enter a valid base url."
  end

  data_test "invalid #{field} displays proper error message", %{conn: conn} do
    smrt_dataset = TDG.create_dataset(%{technical: %{field => %{"foo" => "where's my key"}}})

    {:ok, dataset} = Datasets.update(smrt_dataset)

    assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
    url_form_view = find_live_child(view, "url_form_editor")

    form_data = %{field => %{"0" => %{"key" => "", "value" => "where's my key"}}}

    html = render_change(url_form_view, :validate, %{"form_data" => form_data})

    assert get_text(html, "##{field}-error-msg") == "Please enter valid key(s)."

    where(field: ["sourceQueryParams", "sourceHeaders"])
  end

  test "given a url with at least one invalid query param it marks the dataset as invalid" do
    form_data = %{"sourceUrl" => "https://source.url.example.com?=oops&a=b"} |> FormTools.adjust_source_query_params_for_url()

    changeset = UrlFormSchema.changeset_from_form_data(form_data)

    refute changeset.valid?

    assert {:sourceQueryParams, {"has invalid format", [validation: :format]}} in changeset.errors

    assert %{sourceQueryParams: [%{key: nil, value: "oops"}, %{key: "a", value: "b"}]} = Ecto.Changeset.apply_changes(changeset)
  end
end
