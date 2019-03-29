defmodule DiscoveryApi.Test.Helper do
  @moduledoc false
  alias DiscoveryApi.Data.Dataset

  def sample_dataset(values \\ %{}) do
    %Dataset{
      id: values[:id] || Faker.UUID.v4(),
      title: values[:title] || Faker.Lorem.word(),
      systemName: values[:systemName] || Faker.Lorem.characters(5..10),
      keywords: values[:keywords] || [Faker.Lorem.characters(5), Faker.Lorem.characters(6)],
      organization: values[:organization] || Faker.Lorem.word(),
      modified: values[:modified] || Date.to_string(Faker.Date.backward(20)),
      fileTypes: values[:fileTypes] || [Faker.Lorem.characters(3), Faker.Lorem.characters(4)],
      description: values[:description] || Enum.join(Faker.Lorem.sentences(2..3), " ")
    }
  end
end
