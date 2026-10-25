"! abapGit-based access to the Git remote including login via the abapGit password popup
CLASS zcl_mono_remote_gateway DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_mono_remote_gateway.

  PRIVATE SECTION.
    CONSTANTS max_login_attempts TYPE i VALUE 3.

    METHODS request_credentials
      IMPORTING git_url TYPE string
      RAISING   zcx_mono_global_error.

    METHODS read_default_branch
      IMPORTING git_url       TYPE string
      RETURNING VALUE(result) TYPE string
      RAISING   zcx_abapgit_exception.

ENDCLASS.


CLASS zcl_mono_remote_gateway IMPLEMENTATION.

  METHOD zif_mono_remote_gateway~validate_url.
    TRY.
        zcl_abapgit_repo_srv=>get_instance( )->validate_url( iv_url        = git_url
                                                             iv_chk_exists = abap_false ).
      CATCH zcx_abapgit_exception INTO DATA(error).
        RAISE EXCEPTION TYPE zcx_mono_global_error
          MESSAGE e015(zmono) WITH git_url
          EXPORTING previous = error.
    ENDTRY.
  ENDMETHOD.

  METHOD zif_mono_remote_gateway~connect.
    DATA authenticated TYPE abap_bool.
    DATA error TYPE REF TO zcx_abapgit_exception.

    request_credentials( git_url ).
    DO max_login_attempts TIMES.
      TRY.
          result = read_default_branch( git_url ).
          authenticated = abap_true.
          EXIT.
        CATCH zcx_abapgit_auth_required.
          IF sy-index < max_login_attempts.
            request_credentials( git_url ).
          ENDIF.
        CATCH zcx_abapgit_exception INTO error.
          RAISE EXCEPTION TYPE zcx_mono_global_error
            MESSAGE e011(zmono) WITH git_url
            EXPORTING previous = error.
      ENDTRY.
    ENDDO.

    IF authenticated = abap_false.
      RAISE EXCEPTION TYPE zcx_mono_global_error
        MESSAGE e026(zmono) WITH git_url max_login_attempts.
    ENDIF.
    IF result IS INITIAL.
      RAISE EXCEPTION TYPE zcx_mono_global_error
        MESSAGE e012(zmono) WITH git_url.
    ENDIF.
  ENDMETHOD.

  METHOD zif_mono_remote_gateway~disconnect.
    zcl_abapgit_login_manager=>clear( ).
  ENDMETHOD.

  METHOD request_credentials.
    DATA password TYPE string.

    TRY.
        DATA(user_settings) = zcl_abapgit_persist_factory=>get_user( ).
        DATA(default_login) = user_settings->get_repo_login( git_url ).
        DATA(login) = default_login.

        " Calls FORM password_popup of the running report (INCLUDE zabapgit_password_dialog)
        zcl_abapgit_password_dialog=>popup( EXPORTING iv_repo_url = git_url
                                            CHANGING  cv_user     = login
                                                      cv_pass     = password ).
        IF login IS INITIAL.
          RAISE EXCEPTION TYPE zcx_mono_global_error
            MESSAGE e013(zmono) WITH git_url.
        ENDIF.

        IF login <> default_login.
          user_settings->set_repo_login( iv_url   = git_url
                                         iv_login = login ).
        ENDIF.
        zcl_abapgit_login_manager=>set_basic( iv_uri      = git_url
                                              iv_username = login
                                              iv_password = password ).
      CATCH zcx_abapgit_exception INTO DATA(error).
        RAISE EXCEPTION TYPE zcx_mono_global_error
          MESSAGE e027(zmono) WITH git_url
          EXPORTING previous = error.
    ENDTRY.
  ENDMETHOD.

  METHOD read_default_branch.
    result = zcl_abapgit_git_factory=>get_git_transport( )->branches( git_url )->get_head_symref( ).
  ENDMETHOD.

ENDCLASS.

