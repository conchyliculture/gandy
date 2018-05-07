# Gandy
Small ruby script to update a Gandi domain zone

## Things

Go to [https://doc.livedns.gandi.net/](https://doc.livedns.gandi.net/), get your API key, save it as `.apikey`.

Use a ACME client (such as [my fork of acme-tiny](https://github.com/conchyliculture/acme-tiny/tree/dns-01)) which uses hooks to update your DNS zone.

Write a wrapper around `gandi.rb` to do the things, or if you use my fork, you can call `dns-01.rb`.

This should probably work.
