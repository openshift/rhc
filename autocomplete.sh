#
# This is the bash auto completion script for the rhc command
#
_rhc()
{
  local cur opts prev
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  if [ $COMP_CWORD -eq 1 ]; then
    opts="tail git-clone domain domain-create create-domain domain-update update-domain domain-show show-domain domain-status status-domain domain-delete delete-domain snapshot snapshot-save save-snapshot snapshot-restore restore-snapshot setup apps cartridge cartridge-list list-cartridge cartridge-add add-cartridge cartridge-show show-cartridge cartridge-remove remove-cartridge cartridge-start start-cartridge cartridge-stop stop-cartridge cartridge-restart restart-cartridge cartridge-status status-cartridge cartridge-reload reload-cartridge cartridge-scale scale-cartridge cartridge-storage storage-cartridge app app-create create-app app-delete delete-app app-start start-app app-stop stop-app app-force-stop force-stop-app app-restart restart-app app-reload reload-app app-tidy tidy-app app-show show-app ssh app-ssh ssh-app app-status status-app alias alias-add add-alias alias-remove remove-alias sshkey sshkey-list list-sshkey sshkey-show show-sshkey sshkey-add add-sshkey sshkey-remove remove-sshkey server authorization authorization-add add-authorization authorization-delete delete-authorization authorization-delete-all delete-all-authorization account logout account-logout logout-account threaddump port-forward"
  else
    prev="${COMP_WORDS[@]:0:COMP_CWORD}"
    SAVE_IFS=$IFS
    IFS=" "
    case "${prev[*]}" in

      "rhc tail")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc app")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts="tail git-clone snapshot cartridge create delete destroy start stop force-stop restart reload tidy show ssh status add-alias remove-alias"
        fi
        ;;

      "rhc app tail")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc git-clone")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc app git-clone")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc domain")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts="create update alter show status delete destroy"
        fi
        ;;

      "rhc domain create")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc domain-create")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc create-domain")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc domain update")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc domain alter")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc domain-update")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc update-domain")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc domain show")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc domain-show")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc show-domain")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc domain status")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc domain-status")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc status-domain")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc domain delete")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc domain destroy")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc domain-delete")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc delete-domain")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc snapshot")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts="save restore"
        fi
        ;;

      "rhc app snapshot")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts="save restore"
        fi
        ;;

      "rhc snapshot save")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc app snapshot save")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc snapshot-save")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc save-snapshot")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc snapshot restore")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc app snapshot restore")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc snapshot-restore")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc restore-snapshot")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc setup")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc apps")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc cartridge")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts="list add show remove start stop restart status reload scale storage"
        fi
        ;;

      "rhc app cartridge")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts="list add remove start stop restart status reload"
        fi
        ;;

      "rhc cartridge list")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc app cartridge list")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc cartridge-list")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc list-cartridge")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc cartridge add")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc app cartridge add")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc cartridge-add")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc add-cartridge")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc cartridge show")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc cartridge-show")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc show-cartridge")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc cartridge remove")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc app cartridge remove")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc cartridge-remove")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc remove-cartridge")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc cartridge start")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc app cartridge start")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc cartridge-start")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc start-cartridge")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc cartridge stop")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc app cartridge stop")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc cartridge-stop")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc stop-cartridge")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc cartridge restart")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc app cartridge restart")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc cartridge-restart")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc restart-cartridge")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc cartridge status")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc app cartridge status")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc cartridge-status")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc status-cartridge")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc cartridge reload")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc app cartridge reload")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc cartridge-reload")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc reload-cartridge")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc cartridge scale")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc cartridge-scale")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc scale-cartridge")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc cartridge storage")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc cartridge-storage")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc storage-cartridge")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc app create")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc app-create")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc create-app")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc app delete")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc app destroy")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc app-delete")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc delete-app")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc app start")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc app-start")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc start-app")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc app stop")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc app-stop")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc stop-app")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc app force-stop")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc app-force-stop")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc force-stop-app")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc app restart")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc app-restart")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc restart-app")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc app reload")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc app-reload")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc reload-app")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc app tidy")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc app-tidy")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc tidy-app")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc app show")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc app-show")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc show-app")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc app ssh")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc ssh")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc app-ssh")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc ssh-app")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc app status")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc app-status")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc status-app")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc alias")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts="add remove"
        fi
        ;;

      "rhc alias add")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc app add-alias")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc alias-add")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc add-alias")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc alias remove")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc app remove-alias")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc alias-remove")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc remove-alias")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc sshkey")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts="list show add remove delete"
        fi
        ;;

      "rhc sshkey list")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc sshkey-list")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc list-sshkey")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc sshkey show")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc sshkey-show")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc show-sshkey")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc sshkey add")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc sshkey-add")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc add-sshkey")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc sshkey remove")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc sshkey delete")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc sshkey-remove")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc remove-sshkey")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc server")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc authorization")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts="add delete delete-all"
        fi
        ;;

      "rhc authorization add")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc authorization-add")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc add-authorization")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc authorization delete")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc authorization-delete")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc delete-authorization")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc authorization delete-all")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc authorization-delete-all")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc delete-all-authorization")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc account")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts="logout"
        fi
        ;;

      "rhc account logout")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc logout")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc account-logout")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc logout-account")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc threaddump")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

      "rhc port-forward")
        if [[ "$cur" == -* ]]; then
          opts="--rhlogin LOGIN --password PASSWORD --token TOKEN --debug --server NAME --insecure --ssl-version VERSION --ssl-ca-file FILE --ssl-client-cert-file FILE --timeout SECONDS --noprompt --config FILE --clean --mock"
        else
          opts=""
        fi
        ;;

    esac
    IFS=$SAVE_IFS
  fi

  COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
  return 0
}

complete -o default -F _rhc rhc
