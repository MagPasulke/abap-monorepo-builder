CLASS ltd_package_source DEFINITION FINAL.

  PUBLIC SECTION.
    INTERFACES zif_mono_package_source.

    METHODS add_package
      IMPORTING package_name TYPE devclass
                parent       TYPE devclass OPTIONAL.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF package_entry,
        package_name TYPE devclass,
        parent       TYPE devclass,
      END OF package_entry.

    DATA packages TYPE STANDARD TABLE OF package_entry WITH EMPTY KEY.

ENDCLASS.


CLASS ltd_package_source IMPLEMENTATION.

  METHOD add_package.
    INSERT VALUE #( package_name = package_name
                    parent       = parent ) INTO TABLE packages.
  ENDMETHOD.

  METHOD zif_mono_package_source~select_packages.
    result = VALUE #( FOR entry IN packages WHERE ( package_name IN selection ) ( entry-package_name ) ).
    SORT result BY table_line.
  ENDMETHOD.

  METHOD zif_mono_package_source~get_super_packages.
    DATA parent TYPE devclass.

    DATA(current) = package_name.
    DO.
      parent = VALUE #( packages[ package_name = current ]-parent OPTIONAL ).
      IF parent IS INITIAL.
        RETURN.
      ENDIF.
      INSERT parent INTO TABLE result.
      current = parent.
    ENDDO.
  ENDMETHOD.

  METHOD zif_mono_package_source~get_sub_packages.
    DATA entry TYPE package_entry.

    LOOP AT packages INTO entry WHERE parent = package_name.
      INSERT entry-package_name INTO TABLE result.
      INSERT LINES OF zif_mono_package_source~get_sub_packages( entry-package_name ) INTO TABLE result.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


CLASS ltd_repo_gateway DEFINITION FINAL.

  PUBLIC SECTION.
    INTERFACES zif_mono_repo_gateway.

    METHODS add_existing_repository
      IMPORTING package_name TYPE devclass.

    METHODS fail_push_for
      IMPORTING package_name TYPE devclass.

    METHODS get_created_branch_count
      RETURNING VALUE(result) TYPE i.

    METHODS get_selected_branch_count
      RETURNING VALUE(result) TYPE i.

    METHODS get_online_count
      RETURNING VALUE(result) TYPE i.

  PRIVATE SECTION.
    DATA assignments TYPE zif_mono_types=>repo_assignments.
    DATA failing_pushes TYPE zif_mono_types=>package_names.
    DATA checked_components TYPE zif_mono_types=>package_names.
    DATA configured_repositories TYPE STANDARD TABLE OF zif_mono_types=>repo_key WITH EMPTY KEY.
    DATA created_branches TYPE i.
    DATA selected_branches TYPE i.
    DATA online_count TYPE i.

ENDCLASS.


CLASS ltd_repo_gateway IMPLEMENTATION.

  METHOD add_existing_repository.
    INSERT VALUE #( name         = |{ package_name }|
                    package_name = package_name ) INTO TABLE assignments.
  ENDMETHOD.

  METHOD fail_push_for.
    INSERT package_name INTO TABLE failing_pushes.
  ENDMETHOD.

  METHOD get_created_branch_count.
    result = created_branches.
  ENDMETHOD.

  METHOD get_selected_branch_count.
    result = selected_branches.
  ENDMETHOD.

  METHOD get_online_count.
    result = online_count.
  ENDMETHOD.

  METHOD zif_mono_repo_gateway~list_repositories.
    result = assignments.
  ENDMETHOD.

  METHOD zif_mono_repo_gateway~check_folder_logic.
    INSERT component-root_package INTO TABLE checked_components.
  ENDMETHOD.

  METHOD zif_mono_repo_gateway~create_repository.
    result = component-root_package.
  ENDMETHOD.

  METHOD zif_mono_repo_gateway~configure_repository.
    INSERT repo_key INTO TABLE configured_repositories.
  ENDMETHOD.

  METHOD zif_mono_repo_gateway~switch_online.
    online_count += 1.
  ENDMETHOD.

  METHOD zif_mono_repo_gateway~create_branch.
    created_branches += 1.
  ENDMETHOD.

  METHOD zif_mono_repo_gateway~select_branch.
    selected_branches += 1.
  ENDMETHOD.

  METHOD zif_mono_repo_gateway~push.
    IF line_exists( failing_pushes[ table_line = component-root_package ] ).
      RAISE EXCEPTION TYPE zcx_mono_component_error
        MESSAGE e010(zmono) WITH component-root_package.
    ENDIF.
    result-changed = abap_true.
  ENDMETHOD.

ENDCLASS.


CLASS ltd_remote_gateway DEFINITION FINAL.

  PUBLIC SECTION.
    INTERFACES zif_mono_remote_gateway.

    METHODS is_connected
      RETURNING VALUE(result) TYPE abap_bool.

  PRIVATE SECTION.
    DATA connected TYPE abap_bool.
    DATA validated_url TYPE string.

ENDCLASS.


CLASS ltd_remote_gateway IMPLEMENTATION.

  METHOD is_connected.
    result = connected.
  ENDMETHOD.

  METHOD zif_mono_remote_gateway~validate_url.
    validated_url = git_url.
  ENDMETHOD.

  METHOD zif_mono_remote_gateway~connect.
    connected = abap_true.
    result = `refs/heads/main`.
  ENDMETHOD.

  METHOD zif_mono_remote_gateway~disconnect.
    connected = abap_false.
  ENDMETHOD.

ENDCLASS.


CLASS ltd_pr_client DEFINITION FINAL.

  PUBLIC SECTION.
    INTERFACES zif_mono_pr_client.

    METHODS get_head
      RETURNING VALUE(result) TYPE string.

    METHODS get_base
      RETURNING VALUE(result) TYPE string.

  PRIVATE SECTION.
    DATA head TYPE string.
    DATA base TYPE string.

ENDCLASS.


CLASS ltd_pr_client IMPLEMENTATION.

  METHOD get_head.
    result = head.
  ENDMETHOD.

  METHOD get_base.
    result = base.
  ENDMETHOD.

  METHOD zif_mono_pr_client~create_pull_request.
    me->head = head.
    me->base = base.
    result = `https://github.com/acme/mono/pull/1`.
  ENDMETHOD.

ENDCLASS.


CLASS ltcl_importer DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA package_source TYPE REF TO ltd_package_source.
    DATA repo_gateway TYPE REF TO ltd_repo_gateway.
    DATA remote_gateway TYPE REF TO ltd_remote_gateway.
    DATA pr_client TYPE REF TO ltd_pr_client.

    METHODS setup.
    METHODS imports_all_components FOR TESTING.
    METHODS skips_existing_repository FOR TESTING.
    METHODS push_error_fails_component FOR TESTING.
    METHODS no_pr_without_client FOR TESTING.
    METHODS path_collision_fails_both FOR TESTING.

    METHODS run
      IMPORTING with_pr_client TYPE abap_bool DEFAULT abap_true
      RETURNING VALUE(result)  TYPE REF TO zcl_mono_result.

ENDCLASS.


CLASS ltcl_importer IMPLEMENTATION.

  METHOD setup.
    package_source = NEW #( ).
    package_source->add_package( 'ZAPP' ).
    package_source->add_package( package_name = 'ZAPP_CORE'
                                 parent       = 'ZAPP' ).
    package_source->add_package( 'ZLIB' ).
    repo_gateway = NEW #( ).
    remote_gateway = NEW #( ).
    pr_client = NEW #( ).
  ENDMETHOD.

  METHOD run.
    DATA client TYPE REF TO zif_mono_pr_client.

    IF with_pr_client = abap_true.
      client = pr_client.
    ENDIF.
    DATA(cut) = NEW zcl_mono_importer( package_source = package_source
                                       repo_gateway   = repo_gateway
                                       remote_gateway = remote_gateway
                                       pr_client      = client ).
    result = cut->run( VALUE #( packages     = VALUE #( ( sign = 'I' option = 'CP' low = 'Z*' ) )
                                git_url      = `https://github.com/acme/mono.git`
                                folder_logic = `PREFIX`
                                top_folder   = `abap` ) ).
  ENDMETHOD.

  METHOD imports_all_components.
    DATA(result) = run( ).

    cl_abap_unit_assert=>assert_equals(
      exp = zif_mono_types=>statuses-success
      act = result->get_overall_status( ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = 2
      act = result->count_status( zif_mono_types=>statuses-success ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = 1
      act = repo_gateway->get_created_branch_count( ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = 1
      act = repo_gateway->get_selected_branch_count( ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = 2
      act = repo_gateway->get_online_count( ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = `main`
      act = pr_client->get_base( ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( pr_client->get_head( ) CP `abap-import/*` ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = `https://github.com/acme/mono/pull/1`
      act = result->get_run_info( )-pr_url ).
    cl_abap_unit_assert=>assert_false( remote_gateway->is_connected( ) ).
  ENDMETHOD.

  METHOD skips_existing_repository.
    repo_gateway->add_existing_repository( 'ZLIB' ).

    DATA(result) = run( ).

    cl_abap_unit_assert=>assert_equals(
      exp = zif_mono_types=>statuses-skipped
      act = result->get_status( 'ZLIB' ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = zif_mono_types=>statuses-success
      act = result->get_status( 'ZAPP' ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = zif_mono_types=>statuses-partial
      act = result->get_overall_status( ) ).
  ENDMETHOD.

  METHOD push_error_fails_component.
    repo_gateway->fail_push_for( 'ZAPP' ).

    DATA(result) = run( ).

    DATA(components) = result->get_components( ).
    DATA(app) = components[ root_package = 'ZAPP' ].
    cl_abap_unit_assert=>assert_equals(
      exp = zif_mono_types=>statuses-failed
      act = app-status ).
    cl_abap_unit_assert=>assert_equals(
      exp = zif_mono_types=>steps-on_branch
      act = app-step ).
    cl_abap_unit_assert=>assert_equals(
      exp = zif_mono_types=>statuses-success
      act = result->get_status( 'ZLIB' ) ).
    cl_abap_unit_assert=>assert_not_initial( result->get_run_info( )-pr_url ).
  ENDMETHOD.

  METHOD no_pr_without_client.
    DATA(result) = run( with_pr_client = abap_false ).

    cl_abap_unit_assert=>assert_initial( result->get_run_info( )-pr_url ).
    cl_abap_unit_assert=>assert_not_initial( result->get_run_info( )-pr_hint ).
    cl_abap_unit_assert=>assert_equals(
      exp = zif_mono_types=>statuses-partial
      act = result->get_overall_status( ) ).
  ENDMETHOD.

  METHOD path_collision_fails_both.
    package_source = NEW #( ).
    package_source->add_package( '$ZAPP' ).
    package_source->add_package( 'ZAPP' ).

    DATA(cut) = NEW zcl_mono_importer( package_source = package_source
                                       repo_gateway   = repo_gateway
                                       remote_gateway = remote_gateway
                                       pr_client      = pr_client ).
    DATA(result) = cut->run( VALUE #( packages     = VALUE #( ( sign = 'I' option = 'CP' low = '*ZAPP' ) )
                                      git_url      = `https://github.com/acme/mono.git`
                                      folder_logic = `PREFIX` ) ).

    cl_abap_unit_assert=>assert_equals(
      exp = 2
      act = result->count_status( zif_mono_types=>statuses-failed ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = 0
      act = repo_gateway->get_created_branch_count( ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = zif_mono_types=>statuses-failed
      act = result->get_overall_status( ) ).
  ENDMETHOD.

ENDCLASS.
