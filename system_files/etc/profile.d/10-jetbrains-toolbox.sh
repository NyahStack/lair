#!/usr/bin/env sh

# Add JetBrains Toolbox-generated scripts to PATH when available
JETBRAINS_TOOLBOX_SCRIPTS="${HOME}/.local/share/JetBrains/Toolbox/scripts"
case ":${PATH}:" in
  *:"${JETBRAINS_TOOLBOX_SCRIPTS}":*)
    ;;
  *)
    if [ -d "${JETBRAINS_TOOLBOX_SCRIPTS}" ]; then
      PATH="${JETBRAINS_TOOLBOX_SCRIPTS}:${PATH}"
      export PATH
    fi
    ;;
esac

unset JETBRAINS_TOOLBOX_SCRIPTS
