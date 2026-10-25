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


CLASS ltcl_package_resolver DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA cut TYPE REF TO zcl_mono_package_resolver.

    METHODS setup.
    METHODS nested_selection_merged FOR TESTING RAISING cx_static_check.
    METHODS exclusion_keeps_sub_package FOR TESTING RAISING cx_static_check.
    METHODS unknown_names_ignored FOR TESTING RAISING cx_static_check.
    METHODS no_match_raises FOR TESTING.

ENDCLASS.


CLASS ltcl_package_resolver IMPLEMENTATION.

  METHOD setup.
    DATA(source) = NEW ltd_package_source( ).
    source->add_package( 'ZAPP' ).
    source->add_package( package_name = 'ZAPP_CORE'
                         parent       = 'ZAPP' ).
    source->add_package( package_name = 'ZAPP_CORE_UTIL'
                         parent       = 'ZAPP_CORE' ).
    source->add_package( package_name = 'ZAPP_TEST'
                         parent       = 'ZAPP' ).
    source->add_package( 'ZLIB' ).
    cut = NEW #( source ).
  ENDMETHOD.

  METHOD nested_selection_merged.
    DATA(components) = cut->resolve( VALUE #( ( sign = 'I' option = 'CP' low = 'ZAPP*' ) ) ).

    cl_abap_unit_assert=>assert_equals(
      exp = 1
      act = lines( components ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = 'ZAPP'
      act = components[ 1 ]-root_package ).
    cl_abap_unit_assert=>assert_equals(
      exp = VALUE zif_mono_types=>package_names( ( 'ZAPP_CORE' ) ( 'ZAPP_CORE_UTIL' ) ( 'ZAPP_TEST' ) )
      act = components[ 1 ]-merged_from ).
  ENDMETHOD.

  METHOD exclusion_keeps_sub_package.
    DATA(components) = cut->resolve( VALUE #( ( sign = 'I' option = 'CP' low = 'ZAPP*' )
                                              ( sign = 'E' option = 'EQ' low = 'ZAPP_TEST' ) ) ).

    cl_abap_unit_assert=>assert_equals(
      exp = 1
      act = lines( components ) ).
    cl_abap_unit_assert=>assert_true(
      xsdbool( line_exists( components[ 1 ]-sub_packages[ table_line = 'ZAPP_TEST' ] ) ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = 3
      act = lines( components[ 1 ]-sub_packages ) ).
  ENDMETHOD.

  METHOD unknown_names_ignored.
    DATA(components) = cut->resolve( VALUE #( ( sign = 'I' option = 'EQ' low = 'ZLIB' )
                                              ( sign = 'I' option = 'EQ' low = 'ZNONE' ) ) ).

    cl_abap_unit_assert=>assert_equals(
      exp = 1
      act = lines( components ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = 'ZLIB'
      act = components[ 1 ]-root_package ).
  ENDMETHOD.

  METHOD no_match_raises.
    TRY.
        cut->resolve( VALUE #( ( sign = 'I' option = 'EQ' low = 'ZNONE' ) ) ).
        cl_abap_unit_assert=>fail( `Empty selection must raise an error` ).
      CATCH zcx_mono_global_error ##NO_HANDLER.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
