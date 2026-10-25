"! Package hierarchy from TDEVC and abapGit
CLASS zcl_mono_package_source DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_mono_package_source.

ENDCLASS.


CLASS zcl_mono_package_source IMPLEMENTATION.

  METHOD zif_mono_package_source~select_packages.
    " Range selections cannot use the single record buffer of TDEVC
    SELECT devclass
      FROM tdevc
      WHERE devclass IN @selection
      ORDER BY devclass
      INTO TABLE @result
      BYPASSING BUFFER ##SUBRC_OK.
  ENDMETHOD.

  METHOD zif_mono_package_source~get_super_packages.
    TRY.
        result = zcl_abapgit_factory=>get_sap_package( package_name )->list_superpackages( ).
      CATCH zcx_abapgit_exception INTO DATA(error).
        RAISE EXCEPTION TYPE zcx_mono_global_error
          MESSAGE e019(zmono) WITH package_name
          EXPORTING previous = error.
    ENDTRY.
    DELETE result WHERE table_line = package_name.
  ENDMETHOD.

  METHOD zif_mono_package_source~get_sub_packages.
    result = zcl_abapgit_factory=>get_sap_package( package_name )->list_subpackages( ).
  ENDMETHOD.

ENDCLASS.

