"! Monorepo demo: application
CLASS zcl_mono_demo_app DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Greets a name and renders the greeting
    METHODS run
      IMPORTING name          TYPE string
      RETURNING VALUE(result) TYPE string.
ENDCLASS.


CLASS zcl_mono_demo_app IMPLEMENTATION.

  METHOD run.
    result = NEW zcl_mono_demo_app_ui( )->render( NEW zcl_mono_demo_app_core( )->greet( name ) ).
  ENDMETHOD.

ENDCLASS.

