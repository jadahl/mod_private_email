mod_private_email - Store a users Email address without making it public
========================================================================

In XMPP the way of storing user information such as Email address often is via
vCard services, that store information publicly searchable. In some situations
this method could cause privacy issues, when a user dont want to publish their
Email address, while still wanting to be able to use possible services where an
Email address is required.

This module is a way of storing users Email addresses without causing any
privacy issues by making them public. 

It provides an Ad-hoc command (XEP-0050) interface which lets users on the
server set or clear their Email addresses.


Building & Installation
-----------------------

To build mod_private_email simply run "make".

To install copy the content of the ebin/ directory into ejabberds ebin/
directory.


Configuration
-------------

Here follows a sample configuration which lets any user on "example.net" store
configure their privately stored Email addresses.

{access, mod_private_email, [{allow, {server, "example.net"}}, {deny, all}]}.

{module, [
    ...
    {mod_disco, []}, % Required by mod_adhoc
    {mod_adhoc, []}, % Required by mod_private_email
    {mod_private_email, []},
    ...
]}

