defmodule Estuary.Datasets.DatasetSchema do
  @moduledoc """
  The schema information that estuary persists and references for a given dataset
  """
  def table_schema() do
    [
      table: table_name(),
      schema: schema()
    ]
  end

  def table_name do
    Application.get_env(:estuary, :event_stream_table_name)
  end

  def schema do
    [
      %{
        name: "author",
        type: "string",
        description: "N/A"
      },
      %{
        name: "create_ts",
        type: "long",
        description: "N/A"
      },
      %{
        name: "data",
        type: "string",
        description: "N/A"
      },
      %{
        name: "type",
        type: "string",
        description: "N/A"
      }
    ]
  end

  def parse_args(metadata) do
    [
      %{
        payload: %{
          "author" => to_string(metadata.author),
          "create_ts" => metadata.create_ts,
          "data" => to_string(metadata.data),
          "type" => to_string(metadata.type)
        }
      }
    ]
  end

  def dataset() do
    %{
      author: "reaper",
      create_ts: 1_575_308_549_008,
      data: %{
        business: %{
          authorEmail: nil,
          authorName: nil,
          categories: nil,
          conformsToUri: nil,
          contactEmail: "gis.support@das.ohio.gov",
          contactName: "Jeff Smith",
          dataTitle: "shapeingest_01",
          describedByMimeType: nil,
          describedByUrl: nil,
          description:
            "Cuyahoga County Planning Commission's Greenprint GIS features: Trails, Water Features, Wetlands, Open Space, Activity Nodes, Conservation Areas, Riparian, Watersheds",
          homepage:
            "http://ogrip-geohio.opendata.arcgis.com/datasets/7f805f34eb824474bd874bdfac196fc3_9",
          issuedDate: "2017-03-29T19:23:13.000Z",
          keywords: [
            "Activity Nodes",
            "CCPC",
            "Conservation",
            "Environmental",
            "Greenprint",
            "Open Space",
            "Riparian",
            "Trails",
            "Wetlands"
          ],
          language: nil,
          license: nil,
          modifiedDate: "2017-03-29T19:24:37.000Z",
          orgTitle: "ohio-geographically-referenced-information-program-ogrip",
          parentDataset: nil,
          publishFrequency: nil,
          referenceUrls: nil,
          rights: nil,
          spatial: "-82.1813,41.0898,-81.0999,41.7651",
          temporal: nil
        },
        id: "c455dde7-5549-4899-84e4-shapeingest_01",
        technical: %{
          allow_duplicates: true,
          authHeaders: %{},
          authUrl: nil,
          cadence: "once",
          credentials: false,
          dataName: "c455dde7_5549_4899_84e4_shapeingest_01",
          orgId: "29f35477-6144-443a-bcf5-29bccd97bb1e",
          orgName: "ohio_geographically_referenced_information_program_ogrip",
          private: false,
          protocol: nil,
          schema: [
            %{
              biased: "No",
              demographic: "None",
              description:
                "A column containing the json encoded features that are part of this dataset.",
              masked: "N/A",
              name: "feature",
              pii: "None",
              type: "json"
            }
          ],
          sourceFormat: "application/geo+json",
          sourceHeaders: %{},
          sourceQueryParams: %{},
          sourceType: "ingest",
          sourceUrl:
            "s3://dev-hosted-dataset-files/ohio_geographically_referenced_information_program_ogrip/c455dde7_5549_4899_84e4_shapeingest_01.geojson",
          systemName:
            "ohio_geographically_referenced_information_program_ogrip__c455dde7_5549_4899_84e4_shapeingest_01",
          topLevelSelector: nil
        },
        version: "0.4"
      },
      forwarded: false,
      type: "data:ingest:start"
    }
  end
end
