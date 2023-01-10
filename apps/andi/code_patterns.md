## Splitting LiveView into Components

After coming to this pattern organically, I found a decent read (https://www.wyeworks.com/blog/2020/03/03/breaking-up-a-phoenix-live-view/) that summarizes the pattern. However, the blog does not include guidance on how to navigate changesets, which are the most difficult part of the codebase.

Codebase/Tribal knowledge has been established as follows(At the time of writing, only parts of ingestion page follows this):

### LiveView
- Top-Level component
- Starts a new process
- Can listen to DOM events (handle_event)
- Can listen to pubsub events (handle_info)
- Should nest LiveComponents to encapsulate state (See below)
- Should provide LiveComponents with any information needed from the database/pubsub events
  - This generally means Changesets will be created from the parent LiveView and passed to the LiveComponent
- Generally, do not nest LiveViews, but it is sometime acceptable. (Think iFrame scenarios)
  - Note: There are elixir architectures that encourage nested LiveViews, but the complexity is not worth the benefit from my research


### LiveComponents
- Encapsulates state/logic
- Uses assigns to determine when to re-render
  - If a parent changes the passed down assigns, it will re-render (Think props in react)
  - If the LiveComponent calls the send_update function, it will re-render (Think set_state in react)
- Should NEVER update an assign property passed from the parent directly
  - Use the send() function to broadcast your change to the parent, which will propagate the change back down
- Lives inside the parent LiveViews process - Does not start a new process! Limits race conditions!
- Can receive DOM events (handle_event), but not pubsub events(handle_info)
- Contains a "myself" attribute on the socket that can be used to send DOM events to
  - Inside an embedded HTML template, the attribute is declared as phx-target="<%= @myself %>"



## Ecto Changesets
Changesets are powerful data containers that try to help a bit too much. Changesets attempt to accomplish the following:

From a UI perspective:
- Wrap data
- Integrate with Phoenix.HTML.Form
  - Receive input
  - Trigger change/submit events
  - Display Validation Errors

From a Database Perspective:
- Force data into a schema for easy mapping to the database
- Allow relationships between changesets
- Enforce validations for safe writing
- Utilizes DTO properties to have flexibility of how to perform data transactions (See DTO Perspective)

From a DTO Perspective:
- Allows storage of unmodified data
- Allows registering mutations/changes of data without changing the data
- Allows changes to be programmatically applied or have the :action property set for the database to perform changes


While each of these concepts in isolation are critical to quality development,
when combined all together in a single object responsible for it all, it becomes challenging to use correctly.
Two simple rules can help guide the separation of concerns and increase code maintainability:
- Separate UI Changesets from Database Changesets
- Pass data/validations down from Database changesets to UI Changesets/Nested Changesets

### Problem Statements

```
You change the name of an ingestion.
You do not save it as a draft
You want to see if its a valid name
```

```
You change the name of an ingestion.
You want to see if its a valid name
You discard your changes
```

```
You change the name of the ingestion to something invalid.
You want to save the draft ingestion
You want to have validation on the name
```


### Changeset Constraints
- Changes to the database MUST be in the changeset's :changes property. Underlying data is ignored when inserting/updating to the repo!
  - However, maintaining changes is error-prone, confusing, and unnecessary in most cases.
  - The conceptual work-around is to directly modify the underlying data, but before writing to the repo,
load the existing data and create a changeset from that. This also helps avoid race conditions of the changes in the changeset
getting out of sync of the data in the database.
- Forms will not display errors with :action = nil
- Nested/Associated schemas only correctly get populated through a cast


### Codebase/Tribal knowledge:

### All Changesets
- Must have a changeset function
  - Accepts current data/Changeset and applies the 2nd param as changes
  - Only has basic data type validations
  - Primary way to create/change a changeset
- Must have a validate function, which clears previous errors and attempts to revalidate all data 


### Database Changesets (Top-Level Changesets)
- Live inside a LiveView
- Is placed in andi/input_schemas, not andi_web/input_schemas
- Should match 1-1 with the database schema
- Is allowed to directly save to the database
  - Remember only :changes get applied to the database, so create a new changeset of current data -> new data before inserting 
- Can have data relationships
- Can be used directly in a form (UI Changeset) if convenient, but as soon as the UI form 
starts to diverge from the database schema, opt for creating a separate UI Changeset


### UI Changesets
- Can live inside a LiveView or a LiveComponent
- Should never be directly written to the database
- Is placed in andi_web/input_schemas, not andi/input_schemas 
- Should never have validations, unless they are purely for UI purposes
  - API calls will not use these validations!
  - Database writes will not use these validations!
- Should not have an Ecto ID (It should never be written to the Database!)
- Should be recreated on each render by the parent
  - The parent must map down the appropriate fields if nested changesets!
    - This allows for easy UI schema refactoring, not coupled to a database UI schema
    - This allows for UI refactoring without the need for database migrations...
  - The parent must map down the appropriate errors if nested changesets!
    - Remember, the API calls need to share the validations!
- Must not have the :action property set to nil
  - Forms will not display errors with :action = nil
  - :action can be arbitrary set, preferred is :display_errors

