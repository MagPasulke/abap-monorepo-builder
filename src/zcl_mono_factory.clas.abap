"! Creates the importer with the abapGit-based implementations
CLASS zcl_mono_factory DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Creates the importer; a pull request client is only used for github.com
    CLASS-METHODS create_importer
      IMPORTING git_url       TYPE string
      RETURNING VALUE(result) TYPE REF TO zcl_mono_importer.

    "! Creates the remote gateway
    CLASS-METHODS create_remote_gateway
      RETURNING VALUE(result) TYPE REF TO zif_mono_remote_gateway.

ENDCLASS.


CLASS zcl_mono_factory IMPLEMENTATION.

  METHOD create_importer.
    DATA pr_client TYPE REF TO zif_mono_pr_client.

    IF zcl_mono_pr_client_github=>get_owner_and_repo( git_url ) IS NOT INITIAL.
      pr_client = NEW zcl_mono_pr_client_github( git_url ).
    ENDIF.

    result = NEW #( package_source = NEW zcl_mono_package_source( )
                    repo_gateway   = NEW zcl_mono_repo_gateway( )
                    remote_gateway = create_remote_gateway( )
                    pr_client      = pr_client
                    progress       = zcl_abapgit_progress=>get_instance( 1 ) ).
  ENDMETHOD.

  METHOD create_remote_gateway.
    result = NEW zcl_mono_remote_gateway( ).
  ENDMETHOD.

ENDCLASS.

