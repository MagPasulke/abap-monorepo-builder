"! Monorepo demo: library API
INTERFACE zif_mono_demo_lib_api PUBLIC.

  "! Adds two numbers
  METHODS add
    IMPORTING first         TYPE i
              second        TYPE i
    RETURNING VALUE(result) TYPE i.

ENDINTERFACE.
