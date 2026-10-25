CLASS ltcl_path_builder DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS name_of_simple_package FOR TESTING RAISING cx_static_check.
    METHODS name_of_namespace_package FOR TESTING RAISING cx_static_check.
    METHODS name_of_local_package FOR TESTING RAISING cx_static_check.
    METHODS paths_with_top_folder FOR TESTING RAISING cx_static_check.
    METHODS paths_without_top_folder FOR TESTING RAISING cx_static_check.
    METHODS trailing_slash_removed FOR TESTING RAISING cx_static_check.
    METHODS absolute_top_folder FOR TESTING.
    METHODS parent_segment FOR TESTING.
    METHODS current_segment FOR TESTING.
    METHODS empty_segment FOR TESTING.
    METHODS backslash FOR TESTING.
    METHODS collisions_detected FOR TESTING RAISING cx_static_check.

    METHODS assert_invalid_top_folder
      IMPORTING top_folder TYPE string.

ENDCLASS.


CLASS ltcl_path_builder IMPLEMENTATION.

  METHOD name_of_simple_package.
    cl_abap_unit_assert=>assert_equals(
      exp = `zapp`
      act = NEW zcl_mono_path_builder( `` )->get_component_name( 'ZAPP' ) ).
  ENDMETHOD.

  METHOD name_of_namespace_package.
    cl_abap_unit_assert=>assert_equals(
      exp = `#acme#app`
      act = NEW zcl_mono_path_builder( `` )->get_component_name( '/ACME/APP' ) ).
  ENDMETHOD.

  METHOD name_of_local_package.
    cl_abap_unit_assert=>assert_equals(
      exp = `app`
      act = NEW zcl_mono_path_builder( `` )->get_component_name( '$APP' ) ).
  ENDMETHOD.

  METHOD paths_with_top_folder.
    DATA(components) = VALUE zif_mono_types=>components( ( root_package = 'ZAPP' ) ).

    NEW zcl_mono_path_builder( `abap/backend` )->fill_paths( CHANGING components = components ).

    cl_abap_unit_assert=>assert_equals(
      exp = `abap/backend/zapp`
      act = components[ 1 ]-path ).
    cl_abap_unit_assert=>assert_equals(
      exp = `/abap/backend/zapp/src/`
      act = components[ 1 ]-starting_folder ).
  ENDMETHOD.

  METHOD paths_without_top_folder.
    DATA(components) = VALUE zif_mono_types=>components( ( root_package = '$APP' ) ).

    NEW zcl_mono_path_builder( `` )->fill_paths( CHANGING components = components ).

    cl_abap_unit_assert=>assert_equals(
      exp = `app`
      act = components[ 1 ]-path ).
    cl_abap_unit_assert=>assert_equals(
      exp = `/app/src/`
      act = components[ 1 ]-starting_folder ).
  ENDMETHOD.

  METHOD trailing_slash_removed.
    cl_abap_unit_assert=>assert_equals(
      exp = `abap/backend`
      act = zcl_mono_path_builder=>normalize_top_folder( ` abap/backend/ ` ) ).
  ENDMETHOD.

  METHOD absolute_top_folder.
    assert_invalid_top_folder( `/abap` ).
  ENDMETHOD.

  METHOD parent_segment.
    assert_invalid_top_folder( `abap/../backend` ).
  ENDMETHOD.

  METHOD current_segment.
    assert_invalid_top_folder( `./abap` ).
  ENDMETHOD.

  METHOD empty_segment.
    assert_invalid_top_folder( `abap//backend` ).
  ENDMETHOD.

  METHOD backslash.
    assert_invalid_top_folder( `abap\backend` ).
  ENDMETHOD.

  METHOD collisions_detected.
    DATA(cut) = NEW zcl_mono_path_builder( `` ).
    DATA(components) = VALUE zif_mono_types=>components( ( root_package = '$ZAPP' )
                                                         ( root_package = 'ZAPP' )
                                                         ( root_package = 'ZLIB' ) ).
    cut->fill_paths( CHANGING components = components ).

    cl_abap_unit_assert=>assert_equals(
      exp = VALUE string_table( ( `zapp` ) )
      act = cut->find_path_collisions( components ) ).
  ENDMETHOD.

  METHOD assert_invalid_top_folder.
    TRY.
        zcl_mono_path_builder=>normalize_top_folder( top_folder ).
        cl_abap_unit_assert=>fail( |Top folder { top_folder } must be rejected| ).
      CATCH zcx_mono_global_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
