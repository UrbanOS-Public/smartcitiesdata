defmodule AndiWeb.ExtractHttpStepFormTest do
  use ExUnit.Case
  use Andi.DataCase
  use AndiWeb.Test.AuthConnCase.IntegrationCase
  use Placebo

  import Checkov
  import Phoenix.LiveViewTest
  import SmartCity.Event, only: [ingestion_update: 0, dataset_update: 0]
  import SmartCity.TestHelper, only: [eventually: 1]

  import FlokiHelpers,
    only: [
      find_elements: 2,
      get_attributes: 3,
      get_text: 2,
      get_value: 2,
      get_select: 2
    ]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Andi.InputSchemas.Ingestions

  @url_path "/ingestions/"
  @moduletag shared_data_connection: true
  @instance_name Andi.instance_name()

  describe "http step form edit" do
    setup %{conn: conn} do
      dataset = TDG.create_dataset(%{name: "sample_dataset"})
      ingestion_id = UUID.uuid4()
      http_step = %{context: %{destination: "foo", url: "bar.com", action: "POST", body: "{}"}, id: UUID.uuid4(), type: "http", sequence: 0}

      ingestion =
        TDG.create_ingestion(%{id: ingestion_id, targetDatasets: [dataset.id], name: "sample_ingestion", extractSteps: [http_step]})

      Brook.Event.send(@instance_name, dataset_update(), :andi, dataset)
      Brook.Event.send(@instance_name, ingestion_update(), :andi, ingestion)

      eventually(fn ->
        assert Ingestions.get(ingestion.id) != nil
      end)

      assert {:ok, view, html} = live(conn, "#{@url_path}/#{ingestion.id}")
      [view: view, html: html, http_step: http_step]
    end

    test "url field can be altered and saved", %{
      view: view,
      html: html,
      http_step: http_step
    } do
      new_url = "new_url"

      form_data = %{
        "url" => new_url
      }

      view
      |> form("##{http_step.id}", form_data: form_data)
      |> render_change()

      html = render(view)
      assert get_value(html, "##{http_step.id}_http_url") == new_url
    end

    test "url field shows an error if blank", %{
      view: view,
      html: html,
      http_step: http_step
    } do
      new_url = ""

      form_data = %{
        "url" => new_url
      }

      view
      |> form("##{http_step.id}", form_data: form_data)
      |> render_change()

      html = render(view)
      assert get_text(html, "##{http_step.id}_http_url_error") == "Please enter a valid url - including http:// or https://"
    end

    test "header fields will keep order after double digits", %{view: view, http_step: http_step} do
      new_headers =
        Enum.reduce(0..22, %{}, fn index, acc ->
          view |> element(".url-form__source-headers-add-btn") |> render_click()
          Map.put(acc, "#{index}", %{"key" => "#{index}", "value" => "#{index * 2}"})
        end)

      form_data = %{
        "headers" => new_headers
      }

      view
      |> form("##{http_step.id}", form_data: form_data)
      |> render_change()

      html = render(view)

      elements = find_elements(html, ".url-form__source-headers-key-input")

      assert Enum.count(elements) == 23

      elements
      |> Enum.with_index()
      |> Enum.each(fn {element, index} ->
        element_text =
          Floki.attribute(element, "value")
          |> hd()
          |> String.to_integer()

        assert element_text == index
      end)

      elements = find_elements(html, ".url-form__source-headers-value-input")

      assert Enum.count(elements) == 23

      elements
      |> Enum.with_index()
      |> Enum.each(fn {element, index} ->
        element_text =
          Floki.attribute(element, "value")
          |> hd()
          |> String.to_integer()

        assert element_text == index * 2
      end)
    end

    test "query param fields will keep order after double digits", %{view: view, http_step: http_step} do
      new_headers =
        Enum.reduce(0..22, %{}, fn index, acc ->
          view |> element(".url-form__source-query-params-add-btn") |> render_click()
          Map.put(acc, "#{index}", %{"key" => "#{index}", "value" => "#{index * 2}"})
        end)

      form_data = %{
        "queryParams" => new_headers
      }

      view
      |> form("##{http_step.id}", form_data: form_data)
      |> render_change()

      html = render(view)

      elements = find_elements(html, ".url-form__source-query-params-key-input")

      assert Enum.count(elements) == 23

      elements
      |> Enum.with_index()
      |> Enum.each(fn {element, index} ->
        element_text =
          Floki.attribute(element, "value")
          |> hd()
          |> String.to_integer()

        assert element_text == index
      end)

      elements = find_elements(html, ".url-form__source-query-params-value-input")

      assert Enum.count(elements) == 23

      elements
      |> Enum.with_index()
      |> Enum.each(fn {element, index} ->
        element_text =
          Floki.attribute(element, "value")
          |> hd()
          |> String.to_integer()

        assert element_text == index * 2
      end)
    end
  end
end
