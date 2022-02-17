defmodule Transformers.NoOpFunction do
  # def build() do
  #   fn message -> message end
  # end
  #
  # def build_regex(parameters) do
  #   # extract parameters
  #   # build the function based on params
  # end
  #
  # def parse(:regex_extract) do
  #
  # end
  #
  # def parse(:no_op, parameters) do
  #   fn message -> NoOpFunction.transform(message, parameters) end
  # end

  # def parse(_unsupported, parameters) do
  #   type missmatch -> {:error, "unsupported transformation type #{_unsupported}}
  # end
  #
  # def transform(message, parameters) do
  #   sourceField = Map.get(parameters, "sourceField")
  #   targetField = Map.get(parameters, "targetField")
  #   regex = Map.get(parameters, "regex")
  #
  #   new_string = Regex.replace(regex, sourceField, placement, options \\ [])
  #   put_in(message, [:payload, targetField], new_string)
  #   ALT: put_in(payload, [targetField], new_string])
  #   ALT return {payload | {targetField: new_string}}
  # end
end

# {
#   "type": "regex_extract",
#   "parameters": {
#     "sourceField": "phoneNumber",
#     "targetField": "areaCode",
#     "regex": "^\((\d{3})\)"
#   }
# }
