"! Creates pull requests
INTERFACE zif_mono_pr_client PUBLIC.

  "! Creates a pull request from head into base and returns its URL
  METHODS create_pull_request
    IMPORTING title         TYPE string
              body          TYPE string
              head          TYPE string
              base          TYPE string
    RETURNING VALUE(result) TYPE string
    RAISING   zcx_mono_global_error.

ENDINTERFACE.
