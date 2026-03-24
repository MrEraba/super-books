# Books Recommendation - REST API 


The project is a books recommendations REST API where the users can create|update|delete a recommentation also search and read the recommendations made by other users.

When users hits /books endpoint should have a list of 10 recommendations based on his Preferences (tags) ordered by Creation date.


For the Authentication the project should use JWT tokens.


The recommendations should have the following data:
  - Title
  - Content
  - tags
  - Createt At
  - Owner (User)

The User should have the following data:
  - Email
  - Hashed Password
  - Last Login
  - Preferences (list of tags)

Also we should have the Tag model:
  - title 


