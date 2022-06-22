defmodule AndiWeb.ExtractHttpStepFormTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  use Placebo
  import Checkov

  alias Andi.Services.UrlTest

  @moduletag shared_data_connection: true

  import Phoenix.LiveViewTest
  import SmartCity.TestHelper, only: [eventually: 1]

  import FlokiHelpers,
    only: [
      get_attributes: 3,
      get_values: 2,
      get_text: 2,
      find_elements: 2
    ]

  alias IngestionHelpers

  @endpoint AndiWeb.Endpoint
  @url_path "/ingestions/"

  describe "updating query params" do
    setup do
      ingestion =
        IngestionHelpers.create_with_http_extract_step(%{
          action: "GET",
          url: "test.com",
          queryParams: %{"bar" => "biz", "blah" => "dah"},
          headers: %{"barl" => "biz", "yar" => "har"}
        })

      extract_step_id = IngestionHelpers.get_extract_step_id(ingestion, 0)
      [ingestion: ingestion, extract_step_id: extract_step_id]
    end

    data_test "new key/value inputs are added when add button is pressed for #{field}", %{
      conn: conn,
      ingestion: ingestion,
      extract_step_id: extract_step_id
    } do
      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)
      extract_step_form_view = find_live_child(view, "extract_step_form_editor")

      assert html |> find_elements(key_class) |> length() == 2
      assert html |> find_elements(value_class) |> length() == 2

      add_button = element(extract_step_form_view, "#step-#{extract_step_id} #{btn_class}")
      html = render_click(add_button)

      assert html |> find_elements(key_class) |> length() == 3
      assert html |> find_elements(value_class) |> length() == 3

      where(
        field: [:queryParams, :headers],
        btn_class: [".url-form__source-query-params-add-btn", ".url-form__source-headers-add-btn"],
        key_class: [
          ".url-form__source-query-params-key-input",
          ".url-form__source-headers-key-input"
        ],
        value_class: [
          ".url-form__source-query-params-value-input",
          ".url-form__source-headers-value-input"
        ]
      )
    end

    data_test "key/value inputs are deleted when delete button is pressed for #{field}", %{
      conn: conn,
      ingestion: ingestion,
      extract_step_id: extract_step_id
    } do
      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)
      extract_step_form_view = find_live_child(view, "extract_step_form_editor")

      assert html |> find_elements(key_class) |> length() == 2
      assert html |> find_elements(value_class) |> length() == 2

      btn_id =
        get_attributes(html, btn_class, "phx-value-id")
        |> hd()

      button_selector = "#step-#{extract_step_id} #{btn_class}[phx-value-id='#{btn_id}']"

      del_button = element(extract_step_form_view, button_selector)

      html = render_click(del_button)

      [key_input] = html |> get_attributes(key_class, "class")
      refute btn_id =~ key_input

      [value_input] = html |> get_attributes(value_class, "class")
      refute btn_id =~ value_input

      where(
        field: [:queryParams, :headers],
        btn_class: [
          ".url-form__source-query-params-delete-btn",
          ".url-form__source-headers-delete-btn"
        ],
        key_class: [
          ".url-form__source-query-params-key-input",
          ".url-form__source-headers-key-input"
        ],
        value_class: [
          ".url-form__source-query-params-value-input",
          ".url-form__source-headers-value-input"
        ]
      )
    end

    data_test "does not have key/value inputs when ingestion has no source #{field}", %{conn: conn} do
      ingestion = IngestionHelpers.create_ingestion(%{})
      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)

      assert html |> find_elements(key_class) |> Enum.empty?()
      assert html |> find_elements(value_class) |> Enum.empty?()

      where(
        field: [:queryParams, :headers],
        key_class: [
          ".url-form__source-query-params-key-input",
          ".url-form__source-headers-key-input"
        ],
        value_class: [
          ".url-form__source-query-params-value-input",
          ".url-form__source-headers-value-input"
        ]
      )
    end

    test "url is updated when query params are removed", %{
      conn: conn,
      ingestion: ingestion,
      extract_step_id: extract_step_id
    } do
      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)
      extract_step_form_view = find_live_child(view, "extract_step_form_editor")

      btn_class = ".url-form__source-query-params-delete-btn"
      assert html |> find_elements(btn_class) |> length() == 2

      get_attributes(html, btn_class, "phx-value-id")
      |> Enum.each(fn btn_id ->
        button_selector = "#step-#{extract_step_id} #{btn_class}[phx-value-id='#{btn_id}']"
        del_button = element(extract_step_form_view, button_selector)

        render_click(del_button)
      end)

      url_with_no_query_params =
        ingestion.extractSteps
        |> hd()
        |> get_in([:context, :url])
        |> Andi.URI.clear_query_params()

      html = render(element(extract_step_form_view, "#step-#{extract_step_id}"))

      assert get_values(html, ".extract-http-step-form__url input") == [
               url_with_no_query_params
             ]
    end
  end

  describe "url testing" do
    @tag capture_log: true
    test "uses provided query params and headers", %{conn: conn} do
      ingestion =
        IngestionHelpers.create_with_http_extract_step(%{
          action: "GET",
          url: "123.com",
          queryParams: %{"x" => "y"},
          headers: %{"api-key" => "to-my-heart"}
        })

      extract_step_id = IngestionHelpers.get_extract_step_id(ingestion, 0)

      allow(UrlTest.test(any(), any()), return: %{time: 1_000, status: 200})

      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)
      extract_step_form_view = find_live_child(view, "extract_step_form_editor")
      test_url_button = element(extract_step_form_view, "#step-#{extract_step_id} button", "Test")
      render_click(test_url_button)

      assert_called(UrlTest.test("123.com", query_params: [{"x", "y"}], headers: [{"api-key", "to-my-heart"}]))

      [extract_step_id: extract_step_id]
    end

    data_test "queryParams are updated when query params are added to url", %{conn: conn} do
      ingestion = IngestionHelpers.create_with_http_extract_step(%{})
      extract_step_id = IngestionHelpers.get_extract_step_id(ingestion, 0)

      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)
      extract_step_form_view = find_live_child(view, "extract_step_form_editor")
      es_form = element(extract_step_form_view, "#step-#{extract_step_id} form")

      form_data = %{"url" => url}

      html =
        render_change(es_form, %{
          "form_data" => form_data,
          "_target" => ["form_data", "url"]
        })

      assert get_values(html, ".url-form__source-query-params-key-input") == keys
      assert get_values(html, ".url-form__source-query-params-value-input") == values

      where([
        [:url, :keys, :values],
        ["http://example.com?cat=dog", ["cat"], ["dog"]],
        ["http://example.com?cat=dog&foo=bar", ["cat", "foo"], ["dog", "bar"]],
        ["http://example.com?cat=dog&foo+biz=bar", ["cat", "foo biz"], ["dog", "bar"]],
        ["http://example.com?cat=", ["cat"], [""]],
        ["http://example.com?=dog", [""], ["dog"]]
      ])
    end

    data_test "url is updated when query params are added", %{conn: conn} do
      ingestion = IngestionHelpers.create_with_http_extract_step(%{})
      extract_step_id = IngestionHelpers.get_extract_step_id(ingestion, 0)

      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)
      extract_step_form_view = find_live_child(view, "extract_step_form_editor")
      es_form = element(extract_step_form_view, "#step-#{extract_step_id} form")

      form_data = %{"queryParams" => queryParams, "url" => initialSourceUrl}

      html =
        render_change(es_form, %{
          "form_data" => form_data,
          "_target" => ["form_data", "queryParams"]
        })

      assert get_values(html, ".extract-http-step-form__url input") == [updatedUrl]

      where([
        [:initialSourceUrl, :queryParams, :updatedUrl],
        [
          "http://example.com",
          %{
            "0" => %{"key" => "dog", "value" => "car"},
            "1" => %{"key" => "new", "value" => "thing"}
          },
          "http://example.com?dog=car&new=thing"
        ],
        [
          "http://example.com?dog=cat&fish=water",
          %{"0" => %{"key" => "dog", "value" => "cat"}},
          "http://example.com?dog=cat"
        ],
        ["http://example.com?dog=cat&fish=water", %{}, "http://example.com"],
        [
          "http://example.com?dog=cat",
          %{"0" => %{"key" => "some space", "value" => "thing=whoa"}},
          "http://example.com?some+space=thing%3Dwhoa"
        ]
      ])
    end

    test "status and time are displayed when source url is tested", %{conn: conn} do
      ingestion =
        IngestionHelpers.create_with_http_extract_step(%{
          action: "GET",
          url: "123.com",
          queryParams: %{"x" => "y"},
          headers: %{"api-key" => "to-my-heart"}
        })

      extract_step_id = IngestionHelpers.get_extract_step_id(ingestion, 0)

      allow(UrlTest.test("123.com", any()), return: %{time: 1_000, status: 200})

      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)
      extract_step_form_view = find_live_child(view, "extract_step_form_editor")
      test_url_button = element(extract_step_form_view, "#step-#{extract_step_id} button", "Test")

      assert get_text(html, ".test-status__code") == ""
      assert get_text(html, ".test-status__time") == ""

      render_click(test_url_button)

      eventually(fn ->
        html = render(element(extract_step_form_view, "#step-#{extract_step_id}"))
        assert get_text(html, ".test-status__code") == "Success"
        assert get_text(html, ".test-status__time") == "1000"
      end)
    end

    test "status is displayed with an appropriate class when it is between 200 and 399", %{
      conn: conn
    } do
      ingestion =
        IngestionHelpers.create_with_http_extract_step(%{
          action: "GET",
          url: "123.com",
          queryParams: %{"x" => "y"},
          headers: %{"api-key" => "to-my-heart"}
        })

      extract_step_id = IngestionHelpers.get_extract_step_id(ingestion, 0)

      allow(UrlTest.test("123.com", any()), return: %{time: 1_000, status: 200})

      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)
      extract_step_form_view = find_live_child(view, "extract_step_form_editor")
      test_url_button = element(extract_step_form_view, "#step-#{extract_step_id} button", "Test")

      assert get_text(html, ".test-status__code--good") == ""

      render_click(test_url_button)

      eventually(fn ->
        html = render(element(extract_step_form_view, "#step-#{extract_step_id}"))
        assert get_text(html, ".test-status__code--good") == "Success"
      end)
    end

    test "status is displayed with an appropriate class when it is not between 200 and 399", %{
      conn: conn
    } do
      ingestion =
        IngestionHelpers.create_with_http_extract_step(%{
          action: "GET",
          url: "123.com",
          queryParams: %{"x" => "y"},
          headers: %{"api-key" => "to-my-heart"}
        })

      extract_step_id = IngestionHelpers.get_extract_step_id(ingestion, 0)

      allow(UrlTest.test("123.com", any()), return: %{time: 1_000, status: 400})

      assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)
      extract_step_form_view = find_live_child(view, "extract_step_form_editor")
      test_url_button = element(extract_step_form_view, "#step-#{extract_step_id} button", "Test")

      assert get_text(html, ".test-status__code--bad") == ""

      render_click(test_url_button)

      eventually(fn ->
        html = render(element(extract_step_form_view, "#step-#{extract_step_id}"))
        assert get_text(html, ".test-status__code--bad") == "Error"
        assert get_text(html, ".test-status__code--good") != "Error"
      end)
    end
  end

  test "required url field displays proper error message", %{conn: conn} do
    ingestion =
      IngestionHelpers.create_with_http_extract_step(%{
        action: "GET",
        url: "123.com",
        queryParams: %{"x" => "y"},
        headers: %{"api-key" => "to-my-heart"}
      })

    extract_step_id = IngestionHelpers.get_extract_step_id(ingestion, 0)

    assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)
    extract_step_form_view = find_live_child(view, "extract_step_form_editor")
    es_form = element(extract_step_form_view, "#step-#{extract_step_id} form")

    form_data = %{"url" => ""}

    html = render_change(es_form, %{"form_data" => form_data})

    assert get_text(html, "#url-error-msg") == "Please enter a valid url."
  end

  data_test "invalid #{field} displays proper error message", %{conn: conn} do
    ingestion =
      IngestionHelpers.create_with_http_extract_step(%{
        action: "POST",
        url: "123.com",
        body: "",
        queryParams: %{"x" => "y"},
        headers: %{"api-key" => "to-my-heart"}
      })

    extract_step_id = IngestionHelpers.get_extract_step_id(ingestion, 0)

    assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)
    extract_step_form_view = find_live_child(view, "extract_step_form_editor")
    es_form = element(extract_step_form_view, "#step-#{extract_step_id} form")

    form_data = %{field => value, "action" => "POST", "type" => "http", "url" => "example.com"}

    html = render_change(es_form, %{"form_data" => form_data})

    assert get_text(html, "##{field}-error-msg") == error

    where([
      [:field, :value, :error],
      [
        "queryParams",
        %{"0" => %{"key" => "", "value" => "where's my key"}},
        "Please enter valid key(s)."
      ],
      [
        "headers",
        %{"0" => %{"key" => "", "value" => "where is it?!"}},
        "Please enter valid key(s)."
      ],
      ["body", "this is invalid json", "Please enter valid JSON"]
    ])
  end

  test "body passes validation with valid json", %{conn: conn} do
    ingestion =
      IngestionHelpers.create_with_http_extract_step(%{
        action: "POST",
        url: "123.com",
        body: "",
        queryParams: %{"x" => "y"},
        headers: %{"api-key" => "to-my-heart"}
      })

    extract_step_id = IngestionHelpers.get_extract_step_id(ingestion, 0)

    assert {:ok, view, html} = live(conn, @url_path <> ingestion.id)
    extract_step_form_view = find_live_child(view, "extract_step_form_editor")
    es_form = element(extract_step_form_view, "#step-#{extract_step_id} form")

    form_data = %{"body" => "[{\"bob\": 1}]", "action" => "POST"}

    html = render_change(es_form, %{"form_data" => form_data})

    assert get_text(html, "#body-error-msg") == ""
  end
end
