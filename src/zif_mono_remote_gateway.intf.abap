"! Access to the Git remote including login
INTERFACE zif_mono_remote_gateway PUBLIC.

  "! Checks the syntax of a Git URL
  METHODS validate_url
    IMPORTING git_url TYPE string
    RAISING   zcx_mono_global_error.

  "! Asks for credentials and returns the default branch (HEAD) of the remote
  METHODS connect
    IMPORTING git_url       TYPE string
    RETURNING VALUE(result) TYPE string
    RAISING   zcx_mono_global_error.

  "! Removes all cached credentials
  METHODS disconnect.

ENDINTERFACE.
