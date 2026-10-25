"! abapGit-based repository operations
CLASS zcl_mono_repo_gateway DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_mono_repo_gateway.

  PRIVATE SECTION.
    CONSTANTS remote_dot_abapgit TYPE string VALUE `/.abapgit.xml`.
    CONSTANTS max_warning_texts TYPE i VALUE 3.

    METHODS get_repo
      IMPORTING repo_key      TYPE zif_mono_types=>repo_key
      RETURNING VALUE(result) TYPE REF TO zif_abapgit_repo
      RAISING   zcx_abapgit_exception.

    METHODS get_online_repo
      IMPORTING repo_key      TYPE zif_mono_types=>repo_key
      RETURNING VALUE(result) TYPE REF TO zif_abapgit_repo_online
      RAISING   zcx_abapgit_exception.

    METHODS build_comment
      IMPORTING git_url       TYPE string
                root_package  TYPE devclass
      RETURNING VALUE(result) TYPE zif_abapgit_git_definitions=>ty_comment
      RAISING   zcx_abapgit_exception.

    METHODS collect_warnings
      IMPORTING serialization_log TYPE REF TO zif_abapgit_log
      CHANGING  push_result       TYPE zif_mono_types=>push_result.

ENDCLASS.


CLASS zcl_mono_repo_gateway IMPLEMENTATION.

  METHOD zif_mono_repo_gateway~list_repositories.
    DATA repo TYPE REF TO zif_abapgit_repo.
    DATA assignment TYPE zif_mono_types=>repo_assignment.

    TRY.
        DATA(repos) = zcl_abapgit_repo_srv=>get_instance( )->list( ).
        LOOP AT repos INTO repo.
          assignment = VALUE #( name         = repo->get_name( )
                                package_name = repo->get_package( ) ).
          IF repo->get_local_settings( )-ignore_subpackages = abap_false.
            assignment-sub_packages = zcl_abapgit_factory=>get_sap_package(
                                        assignment-package_name )->list_subpackages( ).
          ENDIF.
          INSERT assignment INTO TABLE result.
        ENDLOOP.
      CATCH zcx_abapgit_exception INTO DATA(error).
        RAISE EXCEPTION TYPE zcx_mono_global_error
          MESSAGE e020(zmono)
          EXPORTING previous = error.
    ENDTRY.
  ENDMETHOD.

  METHOD zif_mono_repo_gateway~check_folder_logic.
    DATA sub_package TYPE devclass.
    DATA error TYPE REF TO zcx_abapgit_exception.

    DATA(dot_abapgit) = zcl_abapgit_dot_abapgit=>build_default( ).
    dot_abapgit->set_folder_logic( folder_logic ).
    dot_abapgit->set_starting_folder( component-starting_folder ).
    DATA(folder_logic_service) = zcl_abapgit_folder_logic=>get_instance( ).

    LOOP AT component-sub_packages INTO sub_package.
      TRY.
          folder_logic_service->package_to_path( iv_top     = component-root_package
                                                 io_dot     = dot_abapgit
                                                 iv_package = sub_package ).
        CATCH zcx_abapgit_exception INTO error.
          RAISE EXCEPTION TYPE zcx_mono_component_error
            MESSAGE e004(zmono) WITH folder_logic sub_package
            EXPORTING previous = error.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_mono_repo_gateway~create_repository.
    TRY.
        DATA(repo) = zcl_abapgit_repo_srv=>get_instance( )->new_offline(
                       iv_name         = |{ component-root_package }|
                       iv_package      = component-root_package
                       iv_folder_logic = folder_logic
                       iv_labels       = zif_mono_types=>repo_label ).
        result = repo->get_key( ).
        COMMIT WORK.
      CATCH zcx_abapgit_exception INTO DATA(error).
        RAISE EXCEPTION TYPE zcx_mono_component_error
          MESSAGE e005(zmono) WITH component-root_package
          EXPORTING previous = error.
    ENDTRY.
  ENDMETHOD.

  METHOD zif_mono_repo_gateway~configure_repository.
    TRY.
        DATA(repo) = get_repo( repo_key ).
        DATA(dot_abapgit) = repo->get_dot_abapgit( ).
        dot_abapgit->set_starting_folder( component-starting_folder ).
        repo->set_dot_abapgit( dot_abapgit ).

        repo = get_repo( repo_key ).
        DATA(settings) = repo->get_local_settings( ).
        settings-display_name = component-path.
        IF NOT line_exists( settings-exclude_remote_paths[ table_line = remote_dot_abapgit ] ).
          INSERT remote_dot_abapgit INTO TABLE settings-exclude_remote_paths.
        ENDIF.
        repo->set_local_settings( settings ).
        COMMIT WORK.
      CATCH zcx_abapgit_exception INTO DATA(error).
        RAISE EXCEPTION TYPE zcx_mono_component_error
          MESSAGE e006(zmono) WITH component-root_package
          EXPORTING previous = error.
    ENDTRY.
  ENDMETHOD.

  METHOD zif_mono_repo_gateway~switch_online.
    TRY.
        get_repo( repo_key )->switch_repo_type( abap_false ).
        DATA(online_repo) = get_online_repo( repo_key ).
        online_repo->set_url( git_url ).
        online_repo->select_branch( branch ).
        COMMIT WORK.
      CATCH zcx_abapgit_exception INTO DATA(error).
        RAISE EXCEPTION TYPE zcx_mono_component_error
          MESSAGE e007(zmono) WITH repo_key
          EXPORTING previous = error.
    ENDTRY.
  ENDMETHOD.

  METHOD zif_mono_repo_gateway~create_branch.
    TRY.
        get_online_repo( repo_key )->create_branch( branch ).
        COMMIT WORK.
      CATCH zcx_abapgit_exception INTO DATA(error).
        RAISE EXCEPTION TYPE zcx_mono_global_error
          MESSAGE e008(zmono) WITH branch
          EXPORTING previous = error.
    ENDTRY.
  ENDMETHOD.

  METHOD zif_mono_repo_gateway~select_branch.
    TRY.
        get_online_repo( repo_key )->select_branch( branch ).
        COMMIT WORK.
      CATCH zcx_abapgit_exception INTO DATA(error).
        RAISE EXCEPTION TYPE zcx_mono_component_error
          MESSAGE e009(zmono) WITH branch repo_key
          EXPORTING previous = error.
    ENDTRY.
  ENDMETHOD.

  METHOD zif_mono_repo_gateway~push.
    DATA local_file TYPE zif_abapgit_definitions=>ty_file_item.

    TRY.
        DATA(online_repo) = get_online_repo( repo_key ).
        online_repo->zif_abapgit_repo~refresh( ).

        " Serialize first with a log to collect warnings; the stage logic reuses the buffered files
        DATA(serialization_log) = NEW zcl_abapgit_log( ).
        online_repo->zif_abapgit_repo~get_files_local( serialization_log ).
        collect_warnings( EXPORTING serialization_log = serialization_log
                          CHANGING  push_result       = result ).

        DATA(files) = zcl_abapgit_stage_logic=>get_stage_logic( )->get( online_repo ).
        result-remote_only_files = lines( files-remote ).

        DATA(stage) = NEW zcl_abapgit_stage( ).
        LOOP AT files-local INTO local_file.
          stage->add( iv_path     = local_file-file-path
                      iv_filename = local_file-file-filename
                      iv_data     = local_file-file-data ).
        ENDLOOP.
        IF stage->count( ) = 0.
          RETURN.
        ENDIF.

        zcl_abapgit_repo_factory=>get_repo_push( online_repo )->push(
          is_comment = build_comment( git_url      = online_repo->get_url( )
                                      root_package = component-root_package )
          io_stage   = stage ).
        result-changed = abap_true.
      CATCH zcx_abapgit_exception INTO DATA(error).
        RAISE EXCEPTION TYPE zcx_mono_component_error
          MESSAGE e010(zmono) WITH component-root_package
          EXPORTING previous = error.
    ENDTRY.
  ENDMETHOD.

  METHOD get_repo.
    result = zcl_abapgit_repo_srv=>get_instance( )->get( repo_key ).
  ENDMETHOD.

  METHOD get_online_repo.
    TRY.
        result = CAST #( get_repo( repo_key ) ).
      CATCH cx_sy_move_cast_error INTO DATA(error).
        zcx_abapgit_exception=>raise_with_text( error ).
    ENDTRY.
  ENDMETHOD.

  METHOD build_comment.
    DATA(user_settings) = zcl_abapgit_persist_factory=>get_user( ).
    DATA(user_record) = zcl_abapgit_env_factory=>get_user_record( ).

    result-committer-name = user_settings->get_repo_git_user_name( git_url ).
    IF result-committer-name IS INITIAL.
      result-committer-name = user_settings->get_default_git_user_name( ).
    ENDIF.
    IF result-committer-name IS INITIAL.
      result-committer-name = user_record->get_name( sy-uname ).
    ENDIF.
    IF result-committer-name IS INITIAL.
      result-committer-name = sy-uname.
    ENDIF.

    result-committer-email = user_settings->get_repo_git_user_email( git_url ).
    IF result-committer-email IS INITIAL.
      result-committer-email = user_settings->get_default_git_user_email( ).
    ENDIF.
    IF result-committer-email IS INITIAL.
      result-committer-email = user_record->get_email( sy-uname ).
    ENDIF.
    IF result-committer-email IS INITIAL.
      result-committer-email = |{ to_lower( sy-uname ) }@localhost|.
    ENDIF.

    result-comment = |Import component { root_package }|.
  ENDMETHOD.

  METHOD collect_warnings.
    DATA texts TYPE string_table.
    DATA log_entry TYPE zif_abapgit_log=>ty_log_out.

    LOOP AT serialization_log->get_messages( ) INTO log_entry
         WHERE type = zif_abapgit_log=>c_status-warning
            OR type = zif_abapgit_log=>c_status-error.
      push_result-warnings += 1.
      IF lines( texts ) < max_warning_texts.
        INSERT log_entry-text INTO TABLE texts.
      ENDIF.
    ENDLOOP.
    push_result-warning_text = concat_lines_of( table = texts
                                                sep   = `; ` ).
  ENDMETHOD.

ENDCLASS.

