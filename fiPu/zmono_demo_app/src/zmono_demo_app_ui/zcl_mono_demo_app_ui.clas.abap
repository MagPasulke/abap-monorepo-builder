"! Monorepo demo: application UI
CLASS zcl_mono_demo_app_ui DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Renders a text as HTML heading
    METHODS render
      IMPORTING text          TYPE string
      RETURNING VALUE(result) TYPE string.
ENDCLASS.


CLASS zcl_mono_demo_app_ui IMPLEMENTATION.

  METHOD render.
    result = |<h1>{ text }</h1>|.
  ENDMETHOD.

ENDCLASS.

