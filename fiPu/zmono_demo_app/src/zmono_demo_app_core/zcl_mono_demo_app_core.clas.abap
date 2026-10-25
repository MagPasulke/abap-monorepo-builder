"! Monorepo demo: application core
CLASS zcl_mono_demo_app_core DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Returns a greeting for a name
    METHODS greet
      IMPORTING name          TYPE string
      RETURNING VALUE(result) TYPE string.
ENDCLASS.


CLASS zcl_mono_demo_app_core IMPLEMENTATION.

  METHOD greet.
    result = |Hello { NEW zcl_mono_demo_app_util( )->to_title( name ) }|.
  ENDMETHOD.

ENDCLASS.

