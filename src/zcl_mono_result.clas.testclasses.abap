CLASS ltcl_result DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA cut TYPE REF TO zcl_mono_result.

    METHODS setup.
    METHODS push_with_changes FOR TESTING.
    METHODS push_without_changes FOR TESTING.
    METHODS push_with_warnings FOR TESTING.
    METHODS pr_body_sections FOR TESTING.
    METHODS overall_success FOR TESTING.
    METHODS overall_partial_without_pr FOR TESTING.
    METHODS overall_failed_on_error FOR TESTING.
    METHODS skip_pending_components FOR TESTING.
    METHODS short_branch_name FOR TESTING.

ENDCLASS.


CLASS ltcl_result IMPLEMENTATION.

  METHOD setup.
    cut = NEW #( `https://github.com/acme/mono.git` ).
    cut->add_component( VALUE #( root_package = 'ZAPP'
                                 path         = `zapp` ) ).
    cut->add_component( VALUE #( root_package = 'ZLIB'
                                 path         = `zlib` ) ).
    cut->set_branch( `refs/heads/abap-import/20261025-120000` ).
  ENDMETHOD.

  METHOD push_with_changes.
    cut->set_push_result( root_package = 'ZAPP'
                          push_result  = VALUE #( changed = abap_true ) ).

    DATA(components) = cut->get_components( ).
    DATA(entry) = components[ root_package = 'ZAPP' ].
    cl_abap_unit_assert=>assert_equals(
      exp = zif_mono_types=>steps-pushed
      act = entry-step ).
    cl_abap_unit_assert=>assert_equals(
      exp = zif_mono_types=>statuses-success
      act = entry-status ).
    cl_abap_unit_assert=>assert_true( cut->has_pushed_components( ) ).
  ENDMETHOD.

  METHOD push_without_changes.
    cut->set_push_result( root_package = 'ZAPP'
                          push_result  = VALUE #( changed = abap_false ) ).

    DATA(components) = cut->get_components( ).
    DATA(entry) = components[ root_package = 'ZAPP' ].
    cl_abap_unit_assert=>assert_equals(
      exp = zif_mono_types=>steps-no_changes
      act = entry-step ).
    cl_abap_unit_assert=>assert_false( cut->has_pushed_components( ) ).
  ENDMETHOD.

  METHOD push_with_warnings.
    cut->set_push_result( root_package = 'ZAPP'
                          push_result  = VALUE #( changed           = abap_true
                                                  warnings          = 2
                                                  remote_only_files = 1 ) ).

    DATA(components) = cut->get_components( ).
    DATA(entry) = components[ root_package = 'ZAPP' ].
    cl_abap_unit_assert=>assert_equals(
      exp = zif_mono_types=>statuses-partial
      act = entry-status ).
    cl_abap_unit_assert=>assert_not_initial( entry-reason ).
  ENDMETHOD.

  METHOD pr_body_sections.
    cut->set_push_result( root_package = 'ZAPP'
                          push_result  = VALUE #( changed = abap_true ) ).
    cut->complete( root_package = 'ZLIB'
                   status       = zif_mono_types=>statuses-failed
                   reason       = |a \| b\nc| ).

    DATA(body) = cut->build_pr_body( ).

    cl_abap_unit_assert=>assert_true( xsdbool( body CS `### Imported (1)` ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( body CS `### Failed (1)` ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( body CS `a \| b c` ) ).
    cl_abap_unit_assert=>assert_false( xsdbool( body CS `### Skipped` ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = `ABAP import: 1 component(s) (abap-import/20261025-120000)`
      act = cut->build_pr_title( ) ).
  ENDMETHOD.

  METHOD overall_success.
    cut->set_push_result( root_package = 'ZAPP'
                          push_result  = VALUE #( changed = abap_true ) ).
    cut->set_push_result( root_package = 'ZLIB'
                          push_result  = VALUE #( changed = abap_false ) ).
    cut->set_pr_url( `https://github.com/acme/mono/pull/1` ).

    cl_abap_unit_assert=>assert_equals(
      exp = zif_mono_types=>statuses-success
      act = cut->get_overall_status( ) ).
  ENDMETHOD.

  METHOD overall_partial_without_pr.
    cut->set_push_result( root_package = 'ZAPP'
                          push_result  = VALUE #( changed = abap_true ) ).
    cut->set_push_result( root_package = 'ZLIB'
                          push_result  = VALUE #( changed = abap_true ) ).

    cl_abap_unit_assert=>assert_equals(
      exp = zif_mono_types=>statuses-partial
      act = cut->get_overall_status( ) ).
  ENDMETHOD.

  METHOD overall_failed_on_error.
    cut->set_global_error( `Remote not reachable` ).

    cl_abap_unit_assert=>assert_equals(
      exp = zif_mono_types=>statuses-failed
      act = cut->get_overall_status( ) ).
  ENDMETHOD.

  METHOD skip_pending_components.
    cut->complete( root_package = 'ZAPP'
                   status       = zif_mono_types=>statuses-failed
                   reason       = `x` ).

    cut->skip_pending( `not processed` ).

    cl_abap_unit_assert=>assert_equals(
      exp = zif_mono_types=>statuses-failed
      act = cut->get_status( 'ZAPP' ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = zif_mono_types=>statuses-skipped
      act = cut->get_status( 'ZLIB' ) ).
  ENDMETHOD.

  METHOD short_branch_name.
    cl_abap_unit_assert=>assert_equals(
      exp = `main`
      act = zcl_mono_result=>get_short_branch_name( `refs/heads/main` ) ).
  ENDMETHOD.

ENDCLASS.
