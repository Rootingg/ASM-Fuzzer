Les graines de la campagne ne sont pas versionnées.

`tests/integration/campaign.sh` les écrit dans un répertoire temporaire :

- `hello` ne doit produire aucun crash avec un seul bitflip ;
- `BRSH` devient `CRSH` au premier bit, et la cible de démonstration faute ;
- le fichier enregistré est comparé à `CRSH`, puis rejoué.

Un fichier de fixture avec une newline finale changerait les octets. Le script utilise `printf` pour garder la longueur exacte.
