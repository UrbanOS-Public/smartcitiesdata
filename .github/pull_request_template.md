## [Ticket Link #111](https://app.zenhub.com/workspaces/mdot-615b97c1a5fde400126174f8/issues/urbanos-public/internal/111)

## Description

- High level overview of changes
- ...

## Reminders:

- [ ] Be mindful of impacts of changing Major/Minor/Patch versions of each elixir app
  - [ ] If updating patch version, are you sure there are no chart changes required to maintain functionality? If so, you should bump minor version instead.
  - [ ] If updating Major or Minor versions , did you update the sauron chart configuration?
- [ ] If changing elixir code in an "app", did you update the relevant version
      in `mix.exs`?
- [ ] If altering an API endpoint, was the relevant postman collection updated?
  - [ ] If a new version of `smart_city` is being used (new fields on a struct), were the relevant postman collections updated?
