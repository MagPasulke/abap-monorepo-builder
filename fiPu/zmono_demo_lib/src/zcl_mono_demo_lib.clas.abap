"! Monorepo demo: library
CLASS zcl_mono_demo_lib DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_mono_demo_lib_api.


ENDCLASS.


CLASS zcl_mono_demo_lib IMPLEMENTATION.

  METHOD zif_mono_demo_lib_api~add.
    result = first + second.
  ENDMETHOD.

ENDCLASS.

