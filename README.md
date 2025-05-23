# Postallow - Automatic Postcreen Allowlist & Blocklist Generator
A script for generating a Postscreen allowlist (and optionally a blocklist) based on large and presumably trustworthy senders' SPF records.

# Why Postallow?
Postallow uses the published SPF records from domains of known webmailers, social networks, ecommerce providers, and compliant bulk senders to generate a list of outbound mailer IP addresses and CIDR ranges to create a allowlist (and optionally a blocklist) for Postfix's Postscreen.

This allows Postscreen to save time and resources by immediately handing off allowlisted connections from these hosts (which we can somewhat safely presume are properly configured) to Postfix's smtpd process for further action. Blocklisted hosts are rejected before they reach Postfix's smtpd process.

Note this does *not* allowlist (or blocklist) email messages from any of these hosts. An allowlist for Postscreen (which is merely the first line of Postfix's defense) merely allows listed hosts to connect to Postfix without further tests to prove they are properly configured and/or legitimate senders. A Postscreen blocklist does nothing but reject the connection based on the blocklisted host's IP.

If all of the allowlist mailers are selected when Postallow runs, the resulting allowlist includes over 500 outbound mail servers, all of which have a very high probability of being properly configured.

# Warning about Blocklisting
By default, Postallow has blocklisting turned off. Most users will not need to ever turn it on, but it's there if you *really* believe you need it. If you choose to enable it, make sure you understand the implications of blocklisting IP addresses based on their hostnames and associated mailers, and re-run Postallow often via cron to make sure you're not inadvertently blocking legitimate senders.

# Requirements
Postallow runs as a shell script (```/bin/sh```) and relies on a script from the <a target="_blank" 
href="https://github.com/spf-tools/spf-tools">SPF-Tools</a> project (**despf.sh**) to help recursively query SPF records. I recommend cloning or copying the entire SPF-Tools repo to a ```/usr/local/scripts/```directory on your system, then confirming the ```spftoolspath``` value in ```postallow.conf```.

In order to run `postallow` you will need:

* A shell
* Perl
* [spf-tools](https://github.com/spf-tools/spf-tools)
* [route-summarization](https://github.com/lquidfire/route-summarization)

**Please update SPF-Tools whenever you update Postallow, as both are under continuous development, and sometimes new features of Postallow depend upon an updated version of SPF-Tools.**

Postallow also assumes that you have **Postfix** and the appropriate **bind-utils** package for your Linux / Unix(-y) system installed on your system. If you don't have Postfix installed, please select so in the file ```postallow.conf```.

# Usage

## As root

1. Make sure you have <a target="_blank" href="https://github.com/spf-tools/spf-tools">SPF-Tools</a> on your system
2. Move the ```postallow.conf``` file to your `/etc/` directory
3. Add any custom hosts to the file ```allowlist_hosts```
4. Run ```/usr/local/scripts/postallow``` (or whereever the script is installed on your system) from the command line.

You can optionally provide a configuration file via the command line which will override the default configuration file:

    /usr/local/scripts/postallow /path/to/config-file

I recommend cloning both the SPF-Tools and the Postallow repos into your ```/usr/local/scripts/``` directory. Once you're satisfied with its performance, set a daily cron job to pick up any new hosts in the mailers' SPF records like this:

    @daily /usr/local/scipts/postallow/postallow > /dev/null 2>&1 #Update Postscreen Allowlists

It is still possible to update the list of known Yahoo! IP outbound mailers from their website weekly:

    @weekly /usr/local/scripts/postallow/scrape_yahoo > /dev/null 2>&1 #Update Yahoo! IPs for Postscreen Allowlists

*(Please read more about Yahoo! hosts below)*

When executed, Postallow will generate a file named ```postscreen_spf_allowlist.cidr```, write it to your Postfix directory, then reload Postfix to pick up any changes.

Add the filename of your allowlist (and optionally your blocklist) to the ```postscreen_access_list``` option in your Postfix ```main.cf``` file, like this:

    postscreen_access_list = permit_mynetworks,
    ...
            cidr:/etc/postfix/postscreen_spf_allowlist.cidr,
            cidr:/etc/postfix/postscreen_spf_blocklist.cidr,
    ...

**IMPORTANT:** If you choose to enable blocklisting, list the blocklist file *after* the allowlist file in ```main.cf```, as shown above. If you misconfigure Postallow and an IP address inadvertently finds its way onto both lists, the first entry "wins." Listing the allowlist file first in ```main.cf``` will assure that allowlisted hosts aren't blocklisted, even if they appear in the blocklist file. 

Then do a manual ```postfix reload``` or re-run ```/usr/local/scripts/postallow``` to build a fresh allowlist and automatically reload Postfix.

## Alternative: Non-root user (needs testing)

1. Make sure you have <a target="_blank" href="https://github.com/spf-tools/spf-tools">SPF-Tools</a> on your system
2. Create a system group: `groupadd -r postallow`
3. Create a system user: `useradd -g postallow -M -r -s /usr/sbin/nologin postallow`
4. Create a directory for postallow in /etc: `mkdir /etc/postallow && chgrp postallow /etc/postallow && chmod g+w /etc/postallow`
5. Move the ```postallow.conf``` file to your `/etc/postallow` directory
6. Change the group of the `yahoo_static_hosts` file to `postallow` (or move it into the the /etc/postallow directory).
7. Use `visudo` to add the following line to your sudo config: `postallow ALL=(ALL) NOPASSWD: /usr/sbin/postfix reload`
8. Add any custom hosts in ```postallow.conf```
9. Run ```/usr/local/scripts/postallow``` from the command line.
10. Copy the generated file(s) `postscreen_spf_allowlist.cidr` (and `postscreen_spf_blocklist.cidr`) to `/etc/postfix/` (or create a symlink).

You can optionally provide a configuration file via the command line which will override the default configuration file:

    /usr/local/scripts/postallow /path/to/config-file

I recommend cloning both the SPF-Tools and the Postallow repos into your ```/usr/local/scripts/``` directory. Once you're satisfied with its performance, set a daily cron job to pick up any new hosts in the mailers' SPF records like this:

    @daily postallow /usr/local/scipts/postallow/postallow > /dev/null 2>&1 #Update Postscreen Allowlists

It is still possible to update the list of known Yahoo! IP outbound mailers from their website weekly:

    @weekly postallow /usr/local/scripts/postallow/scrape_yahoo > /dev/null 2>&1 #Update Yahoo! IPs for Postscreen Allowlists

*(Please read more about Yahoo! hosts below)*

When executed, Postallow will generate a file named ```postscreen_spf_allowlist.cidr```, write it to your Postfix directory, then reload Postfix to pick up any changes.

Add the filename of your allowlist (and optionally your blocklist) to the ```postscreen_access_list``` option in your Postfix ```main.cf``` file, like this:

    postscreen_access_list = permit_mynetworks,
    ...
            cidr:/etc/postfix/postscreen_spf_allowlist.cidr,
            cidr:/etc/postfix/postscreen_spf_blocklist.cidr,
    ...

**IMPORTANT:** If you choose to enable blocklisting, list the blocklist file *after* the allowlist file in ```main.cf```, as shown above. If you misconfigure Postallow and an IP address inadvertently finds its way onto both lists, the first entry "wins." Listing the allowlist file first in ```main.cf``` will assure that allowlisted hosts aren't blocklisted, even if they appear in the blocklist file. 

Then do a manual ```postfix reload``` or re-run ```/usr/local/scripts/postallow``` to build a fresh allowlist and automatically reload Postfix.

# Options
Options for Postallow are located in the ```postallow.conf``` file. This file shoud be moved to your system's ```/etc/``` directory before running Postallow for the first time.

## Custom Hosts
By default, Postallow includes a number of well-known (and presumably trustworthy) mailers in five categories:

* e-mailers
* Ecommerce
* Social Networks
* Bulk Senders
* Miscellaneous

To add your own additional custom hosts, add them to the ```custom_hosts``` section of the file ```allowlist_hosts``` separated by a single space:

    custom_hosts="aol.com google.com microsoft.com"

Additional trusted mailers are added to the script from time to time, so check back periodically for new versions, or "Watch" this repo to receive update notifications.

## Hosts that Don't Publish their Outbound Mailers via SPF Records
Because Postallow relies on published SPF records to build its allowlist, mailers who refuse to publish outbound mailer IP addresses via SPF are problematic.

For smaller mailhosts without SPF-published mailer lists, the included `query_host_ovh` file is a working example of a script that queries a range of hostnames for a specific mailer (`mail-out.ovh.net` in the included example), collects valid IP addresses, and includes them in a custom allowlist. The new custom allowlist may then be included in as an additional entry in your Postfix's `postscreen_access_list` parameter (see **Usage** above).

To create additional customised query scripts for mailers that don't publish outbound IPs via SPF, copy the example `query_host_ovh` file to a new unique filename, edit the script's mailhost and numerical range values as required, set a unique output file (`/etc/postfix/postscreen_*_allowlist.cidr`), include the output file in Postfix's `postscreen_access_list` parameter, then configure cron to run the new query script periodically.

Depending on the size of the range you wish to query, this script could take a long time to complete. I recommend testing on a small fraction of the mailhost's range before pushing the script to a production environment.

## Yahoo! Hosts
The netblocks for Yahoo! are only to be found on their own nameservers, and manual checking of the querying mechanism is required every now and then.

Yahoo also publishes a list of outbound IP addresses [on its website](https://senders.yahooinc.com/outbound-mail-servers/). However, that list does not correspond 100% to the IP addresses obtained from their SPF records via their own nameservers (it would appear that the list on their website shows IP addresses for Yahoo!, Verizon, and AOL). Therefore, Postallow offers both a dynamic list of Yahoo mailers, built from the records obtained from their Nameservers, as well as the option to scrape Yahoo's website and add those IP addresses as well.

A list of Yahoo! outbound IP addresses, based on the linked knowledgebase article and formatted for Postallow, is included as ```yahoo_static_hosts.txt```. By default, the contents of this file are added to the final allowlist. To disable these particular Yahoo! IPs from being included in your allowlist, set the ```include_yahoo``` configuration option in ```/etc/postallow.conf``` to ```include_yahoo="no"```.

The ```yahoo_static_hosts.txt``` file can be periodically updated by running the ```scrape_yahoo``` script, which requires either **Wget** or **cURL** (included on most systems). The ```scrape_yahoo``` script reads the Postallow config file for the location to write the updated list of Yahoo! oubound IP addresses. Run the ```scrape_yahoo``` script periodically via cron (I recommend no more than weekly) to automatically update the list of Yahoo! IPs used by Postallow.

## Blocklisting
To enable blocklisting, set ```enable_blocklist=yes``` and then list blocklisted hosts in ```blocklist_hosts```. Please refer to the blocklisting warning above. Blocklisting is not the primary purpose of Postallow, and most users will never need to turn it on.

## Invalid hosts
You can also choose how to handle malformed or invalid CIDR ranges that appear in the mailers' SPF records (which happens more often than it should). The options are:

* **remove** - the default action, it removes the invalid CIDR range so it doesn't appear in the allowlist.
* **keep** - this keeps the invalid CIDR range in the allowlist. Postfix will log a warning about ```non-null host address bits```, suggest the closest valid range with a matching prefix length, and harmlessly ignore the rule. Useful only if you want to see which mailers are less than careful about their SPF records.
* **fix** - this option will change the invalid CIDR to the closest valid range (the same one suggested by Postfix, in fact) and include the corrected CIDR range in the allowlist.

Other options in ```postallow.conf``` include changing the filenames for your allowlist & blocklist, Postfix path, SPF-Tools path, and whether or not to automatically reload Postfix after you've generated a new list.

# Credits

By the original author:
* Special thanks to Mike Miller for his 2013 <a target="_blank" href="https://archive.mgm51.com/sources/gallowlist.html">gallowlist script</a> that initially got me tinkering with SPF-based Postscreen allowlists. The temp file creation and ```printf``` statement near the end of the Postallow script are remnants of his original script.
* Thanks to Jan Sarenik (author of <a target="_blank" href="https://github.com/jsarenik/spf-tools">SPF-Tools</a>).
* Thanks to <a target="_blank" href="https://github.com/jcbf">Jose Borges Ferreira</a> for patches and contributions to Postallow, include internal code to validate CIDRs.
* Thanks to <a target="_blank" href="https://github.com/corrideat">Ricardo Iván Vieitez Parra</a> for contributions to Postallow, including external config file support, normalization improvements, error handling, and additional modifications that allow Postallow to run on additional systems.
* Thanks to partner (business... not life) <a target="_blank" href="http://stevecook.net/">Steve Cook</a> for helping me cludge through Bash scripting, and for writing the initial version of the ```scrape_yahoo``` script.
* Thanks to all the generous [contributors](https://github.com/stevejenkins/postallow/graphs/contributors) right here on GitHub who have helped move the project along!

# More Info
A blog post by the original author discussing how Postallow came to be is here:

http://www.stevejenkins.com/blog/2015/11/postscreen-allowlisting-smtp-outbound-ip-addresses-large-webmail-providers/

# Suggestions for Additional Mailers
If you're a Postfix admin who sees a good number of ```PASS OLD``` entries for Postscreen in your mail logs, and have a suggestion for an additional mail host that might be a good candidate to include in Postallow, please open an issue for the host(s) to be added to `postallow`.

# Disclaimer
You are totally responsible for anything this script does to your system. You're on your own. :)
