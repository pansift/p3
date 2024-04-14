![pansift_social_v37](https://user-images.githubusercontent.com/4045949/153039199-940a88e8-1a62-4d78-9c74-48094f541336.jpg)

# Intro 

PanSift is a macOS troubleshooting and monitoring tool with a focus on the network. It is for those who support others **remotely** and enables them to rapidly find and fix issues (especially WiFi related). Whether you are a family member doing Zoom calls, a developer, a salesperson, or a gamer - few can afford to be disconnected, interrupted, or slowed down. Pansift makes the invisible visible for a quick fix.

PanSift is about helping clients and teams avoid stress and stay productive by helping to optimize their tools and networks. It's about saving you time, maintaining your and other's situational awareness, and getting to root causes quickly, easily, and **remotely** (even for historical issues!). Whether it's WiFi, DNS, IPv4, IPv6, or HTTP issues - PanSift allows you to keep an eye on multiple remote machines (just like server monitoring) only with a lighter, heavily wireless-focused, and user-friendly agent. More info: [https://pansift.com](https://pansift.com) 
 
# System Status

See [status.pansift.com](https://status.pansift.com) for live operational status.

# Installation

## Attended Installs (Free / Individual Users)

**While logged in as a user, download the [Pansift PKG](https://pansift.com/dl/latest_pkg) and run it.**

You can then claim your agent from the agent's user interface options in your Mac's menubar (under "PS") or do so manually via the web application (using the agent's bucket UUID code). Claiming will require you to sign up for an account at [https://pansift.com](https://app.pansift.com/demo/logout_demo) to view your agent's data and insights. Happy troubleshooting!

## Unattended Installs (Commercial / Managed Service Providers)

Unattended installs assume that an orchestration or MDM (Mobile Device Management) platform is available to you. It also assumes command line and/or custom scripting access within a user's valid session and context (i.e. the targeted user on the machine). This approach also assumes you have paid for > 2 agents and want minimal interaction with the user(s) or endpoint(s) for provisioning.

### Step 1. Targeting New Buckets

For paid accounts (i.e. > 2 agents) please [contact support](https://pansift.com/contact) to have a commercial _multi-agent_ bucket _pre-prepared_ for you in advance (otherwise each agent will get its own bucket on the free platform and lots of individual bucket UUIDs will need to be communicated and claimed individually). We are working to simplify and automate this process.

### Step 2. Automatic Agent Configuration Staging for Multi-Agent Installs

This method is required to **prevent** the ZTP (Zero Touch Provisioning) process from running. It involves **pre-staging** the agent configuration and is required **before** running any PKG installer. It also means you **must** specify custom settings in a pre-install script in advance of any other steps or scripted PKG installs. This ensures that agents will report to your specific nominated bucket from the outset.

Automatic provisioning requires amending portions of the [unattended_preinstall.sh](Toolkit/unattended_preinstall.sh) script and running it on remote machines **before** installing the PKG file. You must customize `3` configuration items (<BUCKET_UUID>, <INGEST_URL>, <ZTP_TOKEN>) in the [unattended_preinstall.sh](Toolkit/unattended_preinstall.sh) **before** deploying the [Pansift PKG](https://pansift.com/dl/latest_pkg) installer. The script is run as **root** but then sudo's to the logged in user to preposition the config files you have customized.

> :information_source: Buckets form one boundary for account-based reads and agent writes. Buckets also define the test host records used by DNS, HTTP, and traces for *all* agents in that bucket. Please consider what agents you want to report in to what buckets. Multiagent buckets allow you to administer a group of agents rather than the default 1-1 agent to bucket mapping.

> :warning: You **must** run the script `unattended_preinstall.sh` script as **root**. It then switches (when necessary) to the logged in user (i.e. the one you presumably wish to target).

*Note:* You can also pre-stage fully populated `pansift_uuid.conf`, `pansift_token.conf`, and `pansift_ingest.conf` yourself if you wish (though this is what the [unattended_preinstall.sh](Scripts/unattended_preinstall.sh) does). You should be able to copy the script to your MDM or orchestration tool's pre-installation script window and ensure it is run while there is a logged-in user.

Once the Pansift.app runs for the first time, it bootstraps its configuration. If the files above are **not** present, it will run the normal ZTP process to get **new and random** bucket details (which you probably **don't want** as then you need to interact with the user or re-push your nominated bucket details and reinstall or restart the agent locally). 

> :warning: Don't forget to run an "agent sync" in the web application after deploying new agents. 

1. Please remember for commercial/mass deployments the [unattended_preinstall.sh](Toolkit/unattended_preinstall.sh) script needs to be able to switch to the context of the user account you intend to implement PanSift's RUM (Real User Monitoring) on. You should also have a full window session available to the script as it also opens the PanSift application. In some MDM platforms you can ensure a script is only run once during login and scoped to a target user (which then ensures a user is logged in during the install).
2. Please [contact support](https://pansift.com/contact) to create a new multi-agent bucket if you require one. You _can_ use an existing bucket if you have claimed one from a free account though data will then reside on the free Influx OSS tier (rather than the commercial Influx cloud).

#### Information on Configuration Files

> :warning: **The below files are auto-generated during standalone installs so you must populate and stage them in advance if you wish to use a multi-agent bucket as per the methods outlined above.**

 * `pansift_uuid.conf` contains a single string comprised of a UUIDv4 value e.g. `84b878ec-da07-490e-8375-c36dfbb098fa`. **YOU CAN NOT ARBITRARILY CREATE IDs YOURSELF**; they must be provisioned in advance. This is actually the bucket UUID that you want the agent to writes to. This bucket UUID is **available** from your account. If you have not claimed any buckets yet or wish to use a new and dedicated bucket then please [contact support](https://pansift.com/contact)

 * `pansift_token.conf` contains a single string comprised of an 86-character hexadecimal string ending in a double equals "==" (so it's 88 characters long). **YOU CAN NOT ARBITRARILY CREATE IDs YOURSELF**; they must be provisioned in advance. This ZTP write token is available from the bucket details in your account. The write token for the bucket can be used by multiple agents hence a 'multiagent' bucket. [Contact support](https://pansift.com/contact) if you are using a "multiagent" bucket and want discrete tokens per agent rather than creating more buckets as a grouping boundary. :warning: **This token only allows writes and not reads to a specific bucket.**

 * `pansift_ingest.conf` contains a single string comprised of a fully qualified URL for the bucket's datastore and ingest host. It takes the form of the `pansift`/`bucket` UUID as the host portion in the `ingest` subdomain. A URL example would be as such; `https://84b878ec-da07-490e-8375-c36dfbb098fa.ingest.pansift.com` (but replace with your UUID), and it needs to resolve in DNS before writes will succeed. This URL tells the agent which datastore host to speak to. The DNS entry is created during the normal ZTP process or by support (so please liaise with support for mass deployments if you are unsure). Please also check the PanSift log for a new agent or [contact support](https://pansift.com/contact) if this is not resolving for you. :information_source: The FQDN(Fully Qualified Domain Name) is a CNAME that points to the datastore A record.

> :warning: **Do not configure the `pansift_ingest.conf` datastore URL with the A record. Use "https://" + the CNAME which follows the pattern of `https://<uuid>.ingest.pansift.com`** otherwise backend operational changes may cause interruptions to your agents' ability to write.

# Uninstalling PanSift

There are three options for uninstalling PanSift:
 1. Click via the agent UI (which opens the terminal and runs the [Uninstall script](Scripts/uninstall.sh) interactively)
 2. Silently via the command line and requires a "-s" command line switch. This second silent approach is for remote administration and is usually used by Managed Service Providers (MSPs) to perform targeted/mass uninstalls.
 3. Package-based uninstall: using the new [PanSift Uninstaller](Pansift_Uninstaller.pkg) package, which you can click to run via the UI (or use the command line to activate once positioned/downloaded, which can also be used by Managed Service Providers (MSPs) to perform targeted/mass uninstalls).
 

## Manual Uninstall

There's an "Uninstall" option in the Agent menu under "PS/Internals/Uninstall/Interactively" (which opens the terminal and goes from there, including asking you to record your configuration if required, or supplying your password). 

Alternatively, you can remove it from your "Login Items" and also delete from "Applications" + stop the Telegraf process (though this is what the [Uninstall script](Scripts/uninstall.sh) does). If the "Uninstall" option is not bringing up your Mac's "Terminal", just open a fresh "Terminal" and click "Uninstall" from the menu again.

## Automatic Uninstall (Silent "-s")

Please use the "-s" silent command line option for unattended uninstalls.

This approach is normally used to run against a machine or machines remotely. The parent process should have root-level permissions, as removing applications from the /Applications folder requires escalated privileges.

Note: If you look at the script, it expects the user under which PanSift was installed, to be logged in. So, even though running with root permissions, `$HOME` should resolve for the current user to ensure the login items are removed, as are the configuration files. 

Please see the uninstall script here: [Uninstall script](Scripts/uninstall.sh)

## Package Based Uninstall

Simply open the [PanSift Uninstaller](Pansift_Uninstaller.pkg) package and follow along. It will ask you for your password and if it can access System Events to remove the PanSift Login Item 

> :information_source: you can also run the [PanSift Uninstaller](Pansift_Uninstaller.pkg) package from the command line as root (or with sudo) via something like: `sudo installer -pkg Pansift_Uninstaller.pkg -target /Applications/` which can be useful in remote management scenarios.
