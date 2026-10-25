"! abapGit repository operations
INTERFACE zif_mono_repo_gateway PUBLIC.

  "! Returns all abapGit repositories with their package trees
  METHODS list_repositories
    RETURNING VALUE(result) TYPE zif_mono_types=>repo_assignments
    RAISING   zcx_mono_global_error.

  "! Checks that the folder logic can map all sub packages of the component
  METHODS check_folder_logic
    IMPORTING component    TYPE zif_mono_types=>component
              folder_logic TYPE string
    RAISING   zcx_mono_component_error.

  "! Creates an offline repository for the component and returns its key
  METHODS create_repository
    IMPORTING component     TYPE zif_mono_types=>component
              folder_logic  TYPE string
    RETURNING VALUE(result) TYPE zif_mono_types=>repo_key
    RAISING   zcx_mono_component_error.

  "! Sets starting folder and display name and excludes the remote root .abapgit.xml
  METHODS configure_repository
    IMPORTING repo_key  TYPE zif_mono_types=>repo_key
              component TYPE zif_mono_types=>component
    RAISING   zcx_mono_component_error.

  "! Switches the repository online and selects a branch
  METHODS switch_online
    IMPORTING repo_key TYPE zif_mono_types=>repo_key
              git_url  TYPE string
              branch   TYPE string
    RAISING   zcx_mono_component_error.

  "! Creates a branch from the selected branch and selects it
  METHODS create_branch
    IMPORTING repo_key TYPE zif_mono_types=>repo_key
              branch   TYPE string
    RAISING   zcx_mono_global_error.

  "! Selects an existing branch
  METHODS select_branch
    IMPORTING repo_key TYPE zif_mono_types=>repo_key
              branch   TYPE string
    RAISING   zcx_mono_component_error.

  "! Pushes all new and changed files; files that exist only in the remote are not deleted
  METHODS push
    IMPORTING repo_key      TYPE zif_mono_types=>repo_key
              component     TYPE zif_mono_types=>component
    RETURNING VALUE(result) TYPE zif_mono_types=>push_result
    RAISING   zcx_mono_component_error.

ENDINTERFACE.
