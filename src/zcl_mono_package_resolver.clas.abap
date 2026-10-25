"! Resolves the package selection into components
CLASS zcl_mono_package_resolver DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Creates the resolver
    METHODS constructor
      IMPORTING package_source TYPE REF TO zif_mono_package_source.

    "! Resolves the selection into components with their complete package tree.
    "! Selected packages below another selected package are merged into the topmost one.
    METHODS resolve
      IMPORTING selection     TYPE zif_mono_types=>package_range
      RETURNING VALUE(result) TYPE zif_mono_types=>components
      RAISING   zcx_mono_global_error.

  PRIVATE SECTION.
    TYPES package_set TYPE HASHED TABLE OF devclass WITH UNIQUE KEY table_line.

    DATA package_source TYPE REF TO zif_mono_package_source.

    METHODS has_selected_super
      IMPORTING package_name  TYPE devclass
                selected      TYPE package_set
      RETURNING VALUE(result) TYPE abap_bool
      RAISING   zcx_mono_global_error.

    METHODS find_root
      IMPORTING package_name  TYPE devclass
                roots         TYPE package_set
      RETURNING VALUE(result) TYPE devclass
      RAISING   zcx_mono_global_error.

ENDCLASS.


CLASS zcl_mono_package_resolver IMPLEMENTATION.

  METHOD constructor.
    me->package_source = package_source.
  ENDMETHOD.

  METHOD resolve.
    DATA roots TYPE zif_mono_types=>package_names.
    DATA merged TYPE zif_mono_types=>package_names.
    DATA candidate TYPE devclass.
    DATA merged_package TYPE devclass.
    DATA root_package TYPE devclass.
    FIELD-SYMBOLS <component> TYPE zif_mono_types=>component.

    DATA(selected) = package_source->select_packages( selection ).
    IF selected IS INITIAL.
      RAISE EXCEPTION TYPE zcx_mono_global_error
        MESSAGE e017(zmono).
    ENDIF.

    DATA(selected_set) = VALUE package_set( FOR selected_package IN selected ( selected_package ) ).
    LOOP AT selected INTO candidate.
      IF has_selected_super( package_name = candidate
                             selected     = selected_set ) = abap_true.
        INSERT candidate INTO TABLE merged.
      ELSE.
        INSERT candidate INTO TABLE roots.
      ENDIF.
    ENDLOOP.

    result = VALUE #( FOR root IN roots
                      ( root_package = root
                        sub_packages = package_source->get_sub_packages( root ) ) ).

    DATA(root_set) = VALUE package_set( FOR root_name IN roots ( root_name ) ).
    LOOP AT merged INTO merged_package.
      root_package = find_root( package_name = merged_package
                                roots        = root_set ).
      READ TABLE result ASSIGNING <component> WITH KEY root_package = root_package.
      IF sy-subrc = 0.
        INSERT merged_package INTO TABLE <component>-merged_from.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD has_selected_super.
    DATA super_package TYPE devclass.

    LOOP AT package_source->get_super_packages( package_name ) INTO super_package.
      IF line_exists( selected[ table_line = super_package ] ).
        result = abap_true.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD find_root.
    DATA super_package TYPE devclass.

    LOOP AT package_source->get_super_packages( package_name ) INTO super_package.
      IF line_exists( roots[ table_line = super_package ] ).
        result = super_package.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

