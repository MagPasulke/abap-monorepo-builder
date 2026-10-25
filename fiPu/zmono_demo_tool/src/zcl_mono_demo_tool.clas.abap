"! Monorepo demo: tool
CLASS zcl_mono_demo_tool DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Counts the words of a text
    METHODS count_words
      IMPORTING text          TYPE string
      RETURNING VALUE(result) TYPE i.
ENDCLASS.


CLASS zcl_mono_demo_tool IMPLEMENTATION.

  METHOD count_words.
    SPLIT condense( text ) AT space INTO TABLE DATA(words).
    result = lines( words ).
  ENDMETHOD.

ENDCLASS.

