# Security

Olook reads mail from strangers, so the parts that handle it are written to
assume the worst: message HTML is rewritten and shown without JavaScript, no
remote content loads until you allow it, links open only when they are web or
mail links, and new passwords and tokens require the keyring, never a command
line or a log. An older private `secrets.json` file may still be read for
accounts created by previous versions; new secrets are never written there.

## Reporting a vulnerability

Please report it privately: open the repository's **Security** tab and choose
**Report a vulnerability**. Include what you did, what happened, and the
version (`omarchy plugin list` shows it).

Please do not open a public issue for a vulnerability before it is fixed.

## Supported versions

Only the latest release gets fixes. `omarchy plugin update ttt.olook` brings
an installed copy up to date.
