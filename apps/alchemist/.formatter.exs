# Used by "mix format"
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  line_length: 120,
  import_deps: [:placebo],
  locals_without_parens: [eventually: :*]
]
