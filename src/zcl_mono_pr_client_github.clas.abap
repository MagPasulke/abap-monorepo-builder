"! Creates pull requests on github.com via the GitHub REST API, reusing the abapGit HTTP agent and login
CLASS zcl_mono_pr_client_github DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_mono_pr_client.

    "! Returns owner/repository of a github.com URL or an empty string for other providers
    CLASS-METHODS get_owner_and_repo
      IMPORTING git_url       TYPE string
      RETURNING VALUE(result) TYPE string.

    "! Creates the client for a github.com repository URL
    METHODS constructor
      IMPORTING git_url TYPE string.

  PRIVATE SECTION.
    CONSTANTS api_url TYPE string VALUE `https://api.github.com/repos/`.

    DATA git_url TYPE string.
    DATA owner_and_repo TYPE string.

    METHODS build_payload
      IMPORTING title         TYPE string
                body          TYPE string
                head          TYPE string
                base          TYPE string
      RETURNING VALUE(result) TYPE string
      RAISING   zcx_abapgit_ajson_error.

    METHODS get_error_details
      IMPORTING response      TYPE REF TO zif_abapgit_http_response
      RETURNING VALUE(result) TYPE string.

ENDCLASS.


CLASS zcl_mono_pr_client_github IMPLEMENTATION.

  METHOD get_owner_and_repo.
    FIND FIRST OCCURRENCE OF PCRE `github\.com[/:]([^/]+)/([^/]+?)(?:\.git)?/?$`
      IN git_url IGNORING CASE
      SUBMATCHES DATA(owner) DATA(repository).
    IF sy-subrc = 0.
      result = |{ owner }/{ repository }|.
    ENDIF.
  ENDMETHOD.

  METHOD constructor.
    me->git_url = git_url.
    owner_and_repo = get_owner_and_repo( git_url ).
  ENDMETHOD.

  METHOD zif_mono_pr_client~create_pull_request.
    DATA status_code TYPE i.
    DATA details TYPE string.

    TRY.
        DATA(agent) = zcl_abapgit_http_agent=>create( ).
        agent->global_headers( )->set( iv_key = `Accept`
                                       iv_val = `application/vnd.github+json` ).
        agent->global_headers( )->set( iv_key = `X-GitHub-Api-Version`
                                       iv_val = `2022-11-28` ).
        DATA(authorization) = zcl_abapgit_login_manager=>get( git_url ).
        IF authorization IS NOT INITIAL.
          agent->global_headers( )->set( iv_key = `Authorization`
                                         iv_val = authorization ).
        ENDIF.

        DATA(response) = agent->request(
                           iv_url     = |{ api_url }{ owner_and_repo }/pulls|
                           iv_method  = zif_abapgit_http_agent=>c_methods-post
                           iv_payload = build_payload( title = title
                                                       body  = body
                                                       head  = head
                                                       base  = base ) ).
        IF response->is_ok( ) = abap_false.
          status_code = response->code( ).
          details = get_error_details( response ).
          RAISE EXCEPTION TYPE zcx_mono_global_error
            MESSAGE e014(zmono) WITH status_code details.
        ENDIF.

        result = response->json( )->get( `/html_url` ).
      CATCH zcx_abapgit_exception zcx_abapgit_ajson_error INTO DATA(error).
        RAISE EXCEPTION TYPE zcx_mono_global_error
          MESSAGE e022(zmono)
          EXPORTING previous = error.
    ENDTRY.
  ENDMETHOD.

  METHOD build_payload.
    DATA(json) = zcl_abapgit_ajson=>new( iv_keep_item_order = abap_true ).
    json->set_string( iv_path = `/title`
                      iv_val  = title ).
    json->set_string( iv_path = `/head`
                      iv_val  = head ).
    json->set_string( iv_path = `/base`
                      iv_val  = base ).
    json->set_string( iv_path = `/body`
                      iv_val  = body ).
    json->set_boolean( iv_path = `/draft`
                       iv_val  = abap_false ).
    result = json->stringify( ).
  ENDMETHOD.

  METHOD get_error_details.
    TRY.
        DATA(json) = response->json( ).
        result = json->get( `/message` ).
        DATA(first_error) = json->get( `/errors/1/message` ).
        IF first_error IS NOT INITIAL.
          result = |{ result }: { first_error }|.
        ENDIF.
      CATCH zcx_abapgit_ajson_error.
        result = response->error( ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.

