defmodule Andi.InputSchemas.DisplayNames do
  @moduledoc false

  @display_names %{
    id: "ID",
    benefitRating: "Benefit",
    contactEmail: "Maintainer Email",
    contactName: "Maintainer Name",
    dataTitle: "Dataset Title",
    description: "Description",
    homepage: "Data Homepage URL",
    issuedDate: "Release Date",
    itemType: "Item Type",
    keywords: "Keywords",
    language: "Language",
    license: "License",
    modifiedDate: "Last Updated",
    orgTitle: "Organization",
    publishFrequency: "Update Frequency",
    spatial: "Spatial Boundaries",
    temporal: "Temporal Boundaries",
    dataName: "Data Name",
    orgName: "Organization Name",
    private: "Level of Access",
    riskRating: "Risk",
    schema: "Schema",
    selector: "Selector",
    sourceFormat: "Source Format",
    sourceHeaders: "Headers",
    sourceQueryParams: "Query Parameters",
    sourceType: "Source Type",
    sourceUrl: "Base URL",
    topLevelSelector: "Top Level Selector",
    name: "Name",
    type: "Type"
  }

  def get(field_key) do
    Map.get(@display_names, field_key)
  end
end
