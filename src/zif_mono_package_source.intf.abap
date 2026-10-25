"! Access to the package hierarchy
INTERFACE zif_mono_package_source PUBLIC.

  "! Returns all existing packages matching the selection, sorted by name
  METHODS select_packages
    IMPORTING selection     TYPE zif_mono_types=>package_range
    RETURNING VALUE(result) TYPE zif_mono_types=>package_names.

  "! Returns all super packages of a package without the package itself, nearest first
  METHODS get_super_packages
    IMPORTING package_name  TYPE devclass
    RETURNING VALUE(result) TYPE zif_mono_types=>package_names
    RAISING   zcx_mono_global_error.

  "! Returns the complete sub package tree of a package without the package itself
  METHODS get_sub_packages
    IMPORTING package_name  TYPE devclass
    RETURNING VALUE(result) TYPE zif_mono_types=>package_names.

ENDINTERFACE.
