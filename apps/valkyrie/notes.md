How do we want this thing to work?

Dataset -> Metadata -> validations
Each dataset might have multiple types of data.
E.g. for a Parking dataset we might have something like (totally making this up):
  Parking Locations -> Validations
  Parking Meters -> Validations

Dataset -> Data -> Valid Data
                -> Invalid Data with reason for why validation failed

Example:
Parking dataset -
{dataset: "parking" type: "locations",
    validations: [{address: [required], name: [string, required],
                  email: [string, email], fee: [required, double],
                  hours: [hour_format]}]}

The validator looks up these names in a validations repository, chain them and applies them for every message. It saves the reasons for failed validation if applicable.                                  


So what is the end goal of this thing? Given a declarative validation generate code like this?

```
defmodule User do
  defstruct username: nil, password: nil, password_confirmation: nil
  use Vex.Struct

  validates :username, presence: true,
                       length: [min: 4],
                       format: ~r/^[[:alpha:]][[:alnum:]]+$/
  validates :password, length: [min: 4],
                       confirmation: true
end
```
What is the short term goal?
I guess is given a simple validation like isNotEmpty - put in Valid othewise put it in Invalid

Read from raw-data topic => write to validated-data topic

```
mix new valkyrie
```