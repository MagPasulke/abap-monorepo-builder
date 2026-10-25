"! Builds component names and folders in the monorepo
CLASS zcl_mono_path_builder DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Validates and normalizes a top folder: relative, without empty, '.' or '..' segments
    CLASS-METHODS normalize_top_folder
      IMPORTING top_folder    TYPE string
      RETURNING VALUE(result) TYPE string
      RAISING   zcx_mono_global_error.

    "! Creates the builder for a top folder (may be empty)
    METHODS constructor
      IMPORTING top_folder TYPE string
      RAISING   zcx_mono_global_error.

    "! Returns the component folder name of a root package, e.g. /ACME/APP becomes #acme#app
    METHODS get_component_name
      IMPORTING root_package  TYPE devclass
      RETURNING VALUE(result) TYPE string.

    "! Sets name, path and starting folder of all components
    METHODS fill_paths
      CHANGING components TYPE zif_mono_types=>components.

    "! Returns all component paths that are used by more than one component
    METHODS find_path_collisions
      IMPORTING components    TYPE zif_mono_types=>components
      RETURNING VALUE(result) TYPE string_table.

  PRIVATE SECTION.
    DATA normalized_top_folder TYPE string.

ENDCLASS.


CLASS zcl_mono_path_builder IMPLEMENTATION.

  METHOD normalize_top_folder.
    result = shift_right( val = shift_left( val = top_folder
                                            sub = ` ` )
                          sub = ` ` ).
    IF result IS INITIAL.
      RETURN.
    ENDIF.

    IF result(1) = '/'.
      RAISE EXCEPTION TYPE zcx_mono_global_error
        MESSAGE e016(zmono) WITH result.
    ENDIF.
    IF result CA '\'.
      RAISE EXCEPTION TYPE zcx_mono_global_error
        MESSAGE e025(zmono) WITH result.
    ENDIF.

    result = shift_right( val = result
                          sub = `/` ).
    SPLIT result AT '/' INTO TABLE DATA(segments).
    IF line_exists( segments[ table_line = `` ] )
        OR line_exists( segments[ table_line = `.` ] )
        OR line_exists( segments[ table_line = `..` ] ).
      RAISE EXCEPTION TYPE zcx_mono_global_error
        MESSAGE e024(zmono) WITH result.
    ENDIF.
  ENDMETHOD.

  METHOD constructor.
    normalized_top_folder = normalize_top_folder( top_folder ).
  ENDMETHOD.

  METHOD get_component_name.
    result = to_lower( shift_left( val = CONV string( root_package )
                                   sub = `$` ) ).
    result = replace( val  = result
                      sub  = `/`
                      with = `#`
                      occ  = 0 ).
  ENDMETHOD.

  METHOD fill_paths.
    LOOP AT components ASSIGNING FIELD-SYMBOL(<component>).
      <component>-name = get_component_name( <component>-root_package ).
      <component>-path = COND #( WHEN normalized_top_folder IS INITIAL
                                 THEN <component>-name
                                 ELSE |{ normalized_top_folder }/{ <component>-name }| ).
      <component>-starting_folder = |/{ <component>-path }/src/|.
    ENDLOOP.
  ENDMETHOD.

  METHOD find_path_collisions.
    DATA used_paths TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
    DATA component TYPE zif_mono_types=>component.

    LOOP AT components INTO component.
      INSERT component-path INTO TABLE used_paths.
      IF sy-subrc <> 0 AND NOT line_exists( result[ table_line = component-path ] ).
        INSERT component-path INTO TABLE result.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

