"! Imports ABAP packages as components into a Git monorepo
CLASS zcl_mono_importer DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Creates the importer; without pull request client no pull request is created
    METHODS constructor
      IMPORTING package_source TYPE REF TO zif_mono_package_source
                repo_gateway   TYPE REF TO zif_mono_repo_gateway
                remote_gateway TYPE REF TO zif_mono_remote_gateway
                pr_client      TYPE REF TO zif_mono_pr_client OPTIONAL
                progress       TYPE REF TO zif_abapgit_progress OPTIONAL.

    "! Runs the import and returns its result
    METHODS run
      IMPORTING parameters    TYPE zif_mono_types=>run_parameters
      RETURNING VALUE(result) TYPE REF TO zcl_mono_result.

  PRIVATE SECTION.
    TYPES package_set TYPE HASHED TABLE OF devclass WITH UNIQUE KEY table_line.

    DATA package_source TYPE REF TO zif_mono_package_source.
    DATA repo_gateway TYPE REF TO zif_mono_repo_gateway.
    DATA remote_gateway TYPE REF TO zif_mono_remote_gateway.
    DATA pr_client TYPE REF TO zif_mono_pr_client.
    DATA progress TYPE REF TO zif_abapgit_progress.
    DATA parameters TYPE zif_mono_types=>run_parameters.
    DATA components TYPE zif_mono_types=>components.
    DATA path_builder TYPE REF TO zcl_mono_path_builder.
    DATA run_result TYPE REF TO zcl_mono_result.
    DATA branch_created TYPE abap_bool.

    METHODS resolve_components
      RAISING zcx_mono_global_error.

    METHODS check_path_collisions.

    METHODS check_existing_repositories
      RAISING zcx_mono_global_error.

    METHODS find_overlap
      IMPORTING component     TYPE zif_mono_types=>component
                assignments   TYPE zif_mono_types=>repo_assignments
      RETURNING VALUE(result) TYPE string.

    METHODS check_folder_logic.

    METHODS connect
      RAISING zcx_mono_global_error.

    METHODS import_components
      RAISING zcx_mono_global_error.

    METHODS import_component
      IMPORTING component TYPE zif_mono_types=>component
      RAISING   zcx_mono_component_error
                zcx_mono_global_error.

    METHODS create_pull_request.

    METHODS fail
      IMPORTING root_package TYPE devclass
                reason       TYPE string.

    METHODS reach
      IMPORTING root_package TYPE devclass
                step         TYPE zif_mono_types=>step.

    METHODS is_pending
      IMPORTING root_package  TYPE devclass
      RETURNING VALUE(result) TYPE abap_bool.

    METHODS show_progress
      IMPORTING current TYPE i
                text    TYPE string.

ENDCLASS.


CLASS zcl_mono_importer IMPLEMENTATION.

  METHOD constructor.
    me->package_source = package_source.
    me->repo_gateway = repo_gateway.
    me->remote_gateway = remote_gateway.
    me->pr_client = pr_client.
    me->progress = progress.
  ENDMETHOD.

  METHOD run.
    DATA reason TYPE string.

    me->parameters = parameters.
    CLEAR: components,
           branch_created.
    run_result = NEW #( parameters-git_url ).
    result = run_result.

    TRY.
        resolve_components( ).
        check_path_collisions( ).
        check_existing_repositories( ).
        check_folder_logic( ).
        IF run_result->count_status( zif_mono_types=>statuses-pending ) > 0.
          connect( ).
          import_components( ).
          create_pull_request( ).
        ENDIF.
      CATCH zcx_mono_global_error INTO DATA(error).
        run_result->set_global_error( error->get_full_text( ) ).
        MESSAGE i023(zmono) INTO reason.
        run_result->skip_pending( reason ).
    ENDTRY.

    remote_gateway->disconnect( ).
  ENDMETHOD.

  METHOD resolve_components.
    DATA component TYPE zif_mono_types=>component.

    components = NEW zcl_mono_package_resolver( package_source )->resolve( parameters-packages ).
    path_builder = NEW #( parameters-top_folder ).
    path_builder->fill_paths( CHANGING components = components ).
    LOOP AT components INTO component.
      run_result->add_component( component ).
    ENDLOOP.
  ENDMETHOD.

  METHOD check_path_collisions.
    DATA reason TYPE string.
    DATA collision_path TYPE string.
    DATA component TYPE zif_mono_types=>component.

    LOOP AT path_builder->find_path_collisions( components ) INTO collision_path.
      MESSAGE e003(zmono) WITH collision_path INTO reason.
      LOOP AT components INTO component WHERE path = collision_path.
        fail( root_package = component-root_package
              reason       = reason ).
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD check_existing_repositories.
    DATA component TYPE zif_mono_types=>component.
    DATA reason TYPE string.

    DATA(assignments) = repo_gateway->list_repositories( ).

    LOOP AT components INTO component.
      IF is_pending( component-root_package ) = abap_false.
        CONTINUE.
      ENDIF.
      reason = find_overlap( component   = component
                             assignments = assignments ).
      IF reason IS NOT INITIAL.
        run_result->complete( root_package = component-root_package
                              status       = zif_mono_types=>statuses-skipped
                              reason       = reason ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD find_overlap.
    DATA assignment TYPE zif_mono_types=>repo_assignment.

    DATA(tree) = VALUE package_set( ( component-root_package )
                                    ( LINES OF component-sub_packages ) ).

    LOOP AT assignments INTO assignment.
      IF assignment-package_name = component-root_package
          OR line_exists( assignment-sub_packages[ table_line = component-root_package ] ).
        MESSAGE e001(zmono) WITH component-root_package assignment-name INTO result.
        RETURN.
      ENDIF.
      IF line_exists( tree[ table_line = assignment-package_name ] ).
        MESSAGE e002(zmono) WITH component-root_package assignment-package_name assignment-name INTO result.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD check_folder_logic.
    DATA component TYPE zif_mono_types=>component.
    DATA error TYPE REF TO zcx_mono_component_error.

    LOOP AT components INTO component.
      IF is_pending( component-root_package ) = abap_false.
        CONTINUE.
      ENDIF.
      TRY.
          repo_gateway->check_folder_logic( component    = component
                                            folder_logic = parameters-folder_logic ).
          reach( root_package = component-root_package
                 step         = zif_mono_types=>steps-checked ).
        CATCH zcx_mono_component_error INTO error.
          fail( root_package = component-root_package
                reason       = error->get_full_text( ) ).
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

  METHOD connect.
    remote_gateway->validate_url( parameters-git_url ).
    run_result->set_default_branch( remote_gateway->connect( parameters-git_url ) ).
    run_result->set_branch( |{ zif_mono_types=>branch_prefix }abap-import/{ sy-datum }-{ sy-uzeit }| ).
  ENDMETHOD.

  METHOD import_components.
    DATA current TYPE i.
    DATA component TYPE zif_mono_types=>component.
    DATA error TYPE REF TO zcx_mono_component_error.
    DATA global_error TYPE REF TO zcx_mono_global_error.

    IF progress IS BOUND.
      progress->set_total( run_result->count_status( zif_mono_types=>statuses-pending ) ).
    ENDIF.

    LOOP AT components INTO component.
      IF is_pending( component-root_package ) = abap_false.
        CONTINUE.
      ENDIF.
      current += 1.
      show_progress( current = current
                     text    = |{ component-root_package }| ).
      TRY.
          import_component( component ).
        CATCH zcx_mono_component_error INTO error.
          fail( root_package = component-root_package
                reason       = error->get_full_text( ) ).
        CATCH zcx_mono_global_error INTO global_error.
          fail( root_package = component-root_package
                reason       = global_error->get_full_text( ) ).
          RAISE EXCEPTION global_error.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

  METHOD import_component.
    DATA(root_package) = component-root_package.
    DATA(run_info) = run_result->get_run_info( ).

    DATA(repo_key) = repo_gateway->create_repository( component    = component
                                                      folder_logic = parameters-folder_logic ).
    reach( root_package = root_package
           step         = zif_mono_types=>steps-created ).

    repo_gateway->configure_repository( repo_key  = repo_key
                                        component = component ).
    reach( root_package = root_package
           step         = zif_mono_types=>steps-configured ).

    repo_gateway->switch_online( repo_key = repo_key
                                 git_url  = parameters-git_url
                                 branch   = run_info-default_branch ).
    reach( root_package = root_package
           step         = zif_mono_types=>steps-online ).

    IF branch_created = abap_false.
      repo_gateway->create_branch( repo_key = repo_key
                                   branch   = run_info-branch ).
      branch_created = abap_true.
    ELSE.
      repo_gateway->select_branch( repo_key = repo_key
                                   branch   = run_info-branch ).
    ENDIF.
    reach( root_package = root_package
           step         = zif_mono_types=>steps-on_branch ).

    run_result->set_push_result( root_package = root_package
                                 push_result  = repo_gateway->push( repo_key  = repo_key
                                                                    component = component ) ).
  ENDMETHOD.

  METHOD create_pull_request.
    DATA hint TYPE string.

    DATA(run_info) = run_result->get_run_info( ).
    DATA(branch) = zcl_mono_result=>get_short_branch_name( run_info-branch ).

    IF run_result->has_pushed_components( ) = abap_false.
      MESSAGE i040(zmono) INTO hint.
      run_result->set_pr_hint( hint ).
      RETURN.
    ENDIF.

    IF pr_client IS NOT BOUND.
      MESSAGE i041(zmono) WITH branch INTO hint.
      run_result->set_pr_hint( hint ).
      RETURN.
    ENDIF.

    TRY.
        run_result->set_pr_url( pr_client->create_pull_request(
          title = run_result->build_pr_title( )
          body  = run_result->build_pr_body( )
          head  = branch
          base  = zcl_mono_result=>get_short_branch_name( run_info-default_branch ) ) ).
      CATCH zcx_mono_global_error INTO DATA(error).
        run_result->set_pr_error( error->get_full_text( ) ).
    ENDTRY.
  ENDMETHOD.

  METHOD fail.
    run_result->complete( root_package = root_package
                          status       = zif_mono_types=>statuses-failed
                          reason       = reason ).
  ENDMETHOD.

  METHOD reach.
    run_result->set_step( root_package = root_package
                          step         = step ).
  ENDMETHOD.

  METHOD is_pending.
    result = xsdbool( run_result->get_status( root_package ) = zif_mono_types=>statuses-pending ).
  ENDMETHOD.

  METHOD show_progress.
    IF progress IS NOT BOUND.
      RETURN.
    ENDIF.
    TRY.
        progress->show( iv_current = current
                        iv_text    = text ).
      CATCH zcx_abapgit_exception ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.

