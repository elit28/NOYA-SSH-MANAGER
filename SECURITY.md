# Politique de sécurité

## Signaler une vulnérabilité

Merci de **ne pas ouvrir de ticket public** pour une faille de sécurité.
Utilisez le signalement privé de GitHub : onglet **Security › Report a vulnerability** de ce dépôt.

Indiquez si possible la version concernée, les étapes de reproduction et l'impact estimé.

## Périmètre

NOYA SSH Manager ne stocke ni mot de passe ni clé privée, ne modifie pas `~/.ssh/config` et n'exécute aucune commande distante. Sont notamment dans le périmètre :

- toute possibilité d'injection de commande ou d'option via un alias ou un fichier importé ;
- toute lecture, copie ou transmission de secrets SSH ;
- toute connexion réseau autre que la vérification TCP du port SSH des serveurs configurés.
