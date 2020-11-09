defmodule AndiWeb.ExtractHttpStepTest do
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

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.InputConverter

  @endpoint AndiWeb.Endpoint
  @url_path "/datasets/"

  describe "updating query params" do
    setup do
      dataset =
        TDG.create_dataset(%{
          technical: %{
            extractSteps: [
              %{
                type: "http",
                context: %{
                  action: "GET",
                  url: "test.com",
                  queryParams: %{"bar" => "biz", "blah" => "dah"},
                  headers: %{"barl" => "biz", "yar" => "har"}
                }
              }
            ]
          }
        })

      {:ok, andi_dataset} = Datasets.update(dataset)
      extract_step_id = get_extract_step_id(andi_dataset, 0)

      [dataset: andi_dataset, extract_step_id: extract_step_id]
    end

    data_test "new key/value inputs are added when add button is pressed for #{field}", %{
      conn: conn,
      dataset: dataset,
      extract_step_id: extract_step_id
    } do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      extract_step_form_view = find_child(view, "extract_step_form_editor")

      assert html |> find_elements(key_class) |> length() == 2
      assert html |> find_elements(value_class) |> length() == 2

      html = render_click([extract_step_form_view, "#step-#{extract_step_id}"], "add", %{"field" => Atom.to_string(field)})

      assert html |> find_elements(key_class) |> length() == 3
      assert html |> find_elements(value_class) |> length() == 3

      where(
        field: [:queryParams, :headers],
        key_class: [".url-form__source-query-params-key-input", ".url-form__source-headers-key-input"],
        value_class: [".url-form__source-query-params-value-input", ".url-form__source-headers-value-input"]
      )
    end

    data_test "key/value inputs are deleted when delete button is pressed for #{field}", %{
      conn: conn,
      dataset: dataset,
      extract_step_id: extract_step_id
    } do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      extract_step_form_view = find_child(view, "extract_step_form_editor")

      assert html |> find_elements(key_class) |> length() == 2
      assert html |> find_elements(value_class) |> length() == 2

      btn_id =
        get_attributes(html, btn_class, "phx-value-id")
        |> hd()

      html =
        render_click([extract_step_form_view, "#step-#{extract_step_id}"], "remove", %{"id" => btn_id, "field" => Atom.to_string(field)})

      [key_input] = html |> get_attributes(key_class, "class")
      refute btn_id =~ key_input

      [value_input] = html |> get_attributes(value_class, "class")
      refute btn_id =~ value_input

      where(
        field: [:queryParams, :headers],
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
        field: [:queryParams, :headers],
        key_class: [".url-form__source-query-params-key-input", ".url-form__source-headers-key-input"],
        value_class: [".url-form__source-query-params-value-input", ".url-form__source-headers-value-input"]
      )
    end

    test "url is updated when query params are removed", %{conn: conn, dataset: dataset, extract_step_id: extract_step_id} do
      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      extract_step_form_view = find_child(view, "extract_step_form_editor")

      assert html |> find_elements(".url-form__source-query-params-delete-btn") |> length() == 2

      get_attributes(html, ".url-form__source-query-params-delete-btn", "phx-value-id")
      |> Enum.each(fn btn_id ->
        render_click([extract_step_form_view, "#step-#{extract_step_id}"], "remove", %{
          "id" => btn_id,
          "field" => Atom.to_string(:queryParams)
        })
      end)

      url_with_no_query_params =
        dataset.technical.extractSteps
        |> hd()
        |> get_in([:context, :url])
        |> Andi.URI.clear_query_params()

      assert render([extract_step_form_view, "#step-#{extract_step_id}"]) |> get_values(".extract-http-step-form__url input") == [
               url_with_no_query_params
             ]
    end
  end

  describe "url testing" do
    @tag capture_log: true
    test "uses provided query params and headers", %{conn: conn} do
      smrt_dataset =
        TDG.create_dataset(%{
          technical: %{
            extractSteps: [
              %{
                type: "http",
                context: %{
                  action: "GET",
                  url: "123.com",
                  queryParams: %{"x" => "y"},
                  headers: %{"api-key" => "to-my-heart"}
                }
              }
            ]
          }
        })

      {:ok, dataset} = Datasets.update(smrt_dataset)
      extract_step_id = get_extract_step_id(dataset, 0)

      allow(UrlTest.test(any(), any()), return: %{time: 1_000, status: 200})

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      extract_step_form_view = find_child(view, "extract_step_form_editor")
      render_change([extract_step_form_view, "#step-#{extract_step_id}"], :test_url, %{})

      assert_called(UrlTest.test("123.com", query_params: [{"x", "y"}], headers: [{"api-key", "to-my-heart"}]))

      [extract_step_id: extract_step_id]
    end

    data_test "queryParams are updated when query params are added to url", %{conn: conn} do
      smrt_dataset = TDG.create_dataset(%{technical: %{extractSteps: [%{type: "http", context: %{}}]}})

      {:ok, dataset} = Datasets.update(smrt_dataset)
      extract_step_id = get_extract_step_id(dataset, 0)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      extract_step_form_view = find_child(view, "extract_step_form_editor")

      form_data = %{"url" => url}

      html =
        render_change([extract_step_form_view, "#step-#{extract_step_id}"], :validate, %{
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
      smrt_dataset = TDG.create_dataset(%{technical: %{extractSteps: [%{type: "http", context: %{}}]}})

      {:ok, dataset} = Datasets.update(smrt_dataset)
      extract_step_id = get_extract_step_id(dataset, 0)

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      extract_step_form_view = find_child(view, "extract_step_form_editor")

      form_data = %{"queryParams" => queryParams, "url" => initialSourceUrl}

      html =
        render_change([extract_step_form_view, "#step-#{extract_step_id}"], :validate, %{
          "form_data" => form_data,
          "_target" => ["form_data", "queryParams"]
        })

      assert get_values(html, ".extract-http-step-form__url input") == [updatedUrl]

      where([
        [:initialSourceUrl, :queryParams, :updatedUrl],
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
      smrt_dataset =
        TDG.create_dataset(%{
          technical: %{
            extractSteps: [
              %{
                type: "http",
                context: %{
                  action: "GET",
                  url: "123.com",
                  queryParams: %{"x" => "y"},
                  headers: %{"api-key" => "to-my-heart"}
                }
              }
            ]
          }
        })

      {:ok, dataset} = Datasets.update(smrt_dataset)
      extract_step_id = get_extract_step_id(dataset, 0)

      allow(UrlTest.test("123.com", any()), return: %{time: 1_000, status: 200})

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      extract_step_form_view = find_child(view, "extract_step_form_editor")

      assert get_text(html, ".test-status__code") == ""
      assert get_text(html, ".test-status__time") == ""

      render_change([extract_step_form_view, "#step-#{extract_step_id}"], :test_url, %{})

      eventually(fn ->
        html = render([extract_step_form_view, "#step-#{extract_step_id}"])
        assert get_text(html, ".test-status__code") == "Success"
        assert get_text(html, ".test-status__time") == "1000"
      end)
    end

    test "status is displayed with an appropriate class when it is between 200 and 399", %{conn: conn} do
      smrt_dataset =
        TDG.create_dataset(%{
          technical: %{
            extractSteps: [
              %{
                type: "http",
                context: %{
                  action: "GET",
                  url: "123.com",
                  queryParams: %{"x" => "y"},
                  headers: %{"api-key" => "to-my-heart"}
                }
              }
            ]
          }
        })

      {:ok, dataset} = Datasets.update(smrt_dataset)
      extract_step_id = get_extract_step_id(dataset, 0)

      allow(UrlTest.test("123.com", any()), return: %{time: 1_000, status: 200})

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      extract_step_form_view = find_child(view, "extract_step_form_editor")

      assert get_text(html, ".test-status__code--good") == ""

      render_change([extract_step_form_view, "#step-#{extract_step_id}"], :test_url, %{})

      eventually(fn ->
        html = render([extract_step_form_view, "#step-#{extract_step_id}"])
        assert get_text(html, ".test-status__code--good") == "Success"
      end)
    end

    test "status is displayed with an appropriate class when it is not between 200 and 399", %{conn: conn} do
      smrt_dataset =
        TDG.create_dataset(%{
          technical: %{
            extractSteps: [
              %{
                type: "http",
                context: %{
                  action: "GET",
                  url: "123.com",
                  queryParams: %{"x" => "y"},
                  headers: %{"api-key" => "to-my-heart"}
                }
              }
            ]
          }
        })

      {:ok, dataset} = Datasets.update(smrt_dataset)
      extract_step_id = get_extract_step_id(dataset, 0)

      allow(UrlTest.test("123.com", any()), return: %{time: 1_000, status: 400})

      assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
      extract_step_form_view = find_child(view, "extract_step_form_editor")

      assert get_text(html, ".test-status__code--bad") == ""

      render_change([extract_step_form_view, "#step-#{extract_step_id}"], :test_url, %{})

      eventually(fn ->
        html = render([extract_step_form_view, "#step-#{extract_step_id}"])
        assert get_text(html, ".test-status__code--bad") == "Error"
        assert get_text(html, ".test-status__code--good") != "Error"
      end)
    end
  end

  test "required url field displays proper error message", %{conn: conn} do
    smrt_dataset =
      TDG.create_dataset(%{
        technical: %{
          extractSteps: [
            %{
              type: "http",
              context: %{
                action: "GET",
                url: "123.com",
                queryParams: %{"x" => "y"},
                headers: %{"api-key" => "to-my-heart"}
              }
            }
          ]
        }
      })

    {:ok, dataset} =
      InputConverter.smrt_dataset_to_draft_changeset(smrt_dataset)
      |> Datasets.save()

    extract_step_id = get_extract_step_id(dataset, 0)

    assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
    extract_step_form_view = find_child(view, "extract_step_form_editor")

    form_data = %{"url" => ""}

    html = render_change([extract_step_form_view, "#step-#{extract_step_id}"], :validate, %{"form_data" => form_data})

    assert get_text(html, "#url-error-msg") == "Please enter a valid url."
  end

  data_test "invalid #{field} displays proper error message", %{conn: conn} do
    smrt_dataset =
      TDG.create_dataset(%{
        technical: %{
          extractSteps: [
            %{
              type: "http",
              context: %{
                action: "POST",
                url: "123.com",
                body: "",
                queryParams: %{"x" => "y"},
                headers: %{"api-key" => "to-my-heart"}
              }
            }
          ]
        }
      })

    {:ok, dataset} = Datasets.update(smrt_dataset)
    extract_step_id = get_extract_step_id(dataset, 0)

    assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
    extract_step_form_view = find_child(view, "extract_step_form_editor")

    form_data = %{field => value, "action" => "POST", "type" => "http", "url" => "example.com"}

    html = render_change([extract_step_form_view, "#step-#{extract_step_id}"], :validate, %{"form_data" => form_data})

    assert get_text(html, "##{field}-error-msg") == error

    where([
      [:field, :value, :error],
      ["queryParams", %{"0" => %{"key" => "", "value" => "where's my key"}}, "Please enter valid key(s)."],
      ["headers", %{"0" => %{"key" => "", "value" => "where is it?!"}}, "Please enter valid key(s)."],
      ["body", "this is invalid json", "Please enter valid JSON"]
    ])
  end

  test "body passes validation with valid json", %{conn: conn} do
    smrt_dataset =
      TDG.create_dataset(%{
        technical: %{
          extractSteps: [
            %{
              type: "http",
              context: %{
                action: "POST",
                url: "123.com",
                body: "",
                queryParams: %{"x" => "y"},
                headers: %{"api-key" => "to-my-heart"}
              }
            }
          ]
        }
      })

    {:ok, dataset} = Datasets.update(smrt_dataset)
    extract_step_id = get_extract_step_id(dataset, 0)

    assert {:ok, view, html} = live(conn, @url_path <> dataset.id)
    extract_step_form_view = find_child(view, "extract_step_form_editor")

    form_data = %{"body" => "[{\"bob\": 1}]", "action" => "POST"}

    html = render_change([extract_step_form_view, "#step-#{extract_step_id}"], :validate, %{"form_data" => form_data})

    assert get_text(html, "#body-error-msg") == ""
  end

  defp get_extract_step_id(dataset, index) do
    dataset
    |> Andi.InputSchemas.StructTools.to_map()
    |> get_in([:technical, :extractSteps])
    |> Enum.at(index)
    |> Map.get(:id)
  end
end
