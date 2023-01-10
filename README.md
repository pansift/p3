![pansift_social_v37](https://user-images.githubusercontent.com/4045949/153039199-940a88e8-1a62-4d78-9c74-48094f541336.jpg)

# Intro 

Pansift is a macOS troubleshooting and monitoring tool with a focus on the network. It is for those who support others **remotely** and enables them to rapidly find and fix issues (especially WiFi related). Whether you are a family member doing Zoom calls, a developer, a salesperson, or a gamer who can't afford to be disconnected, interrupted, or slowed down, Pansift makes the invisible visible for a quick fix.

Pansift is about helping others to avoid stress and stay productive with optimally functioning tools and networks. It's about saving you time, maintaining situational awareness, and getting to root causes quickly, easily, and **remotely** (even for historical issues). Whether it's for WiFi, DNS, IPv4, IPv6, or simple disk utilization issues - PanSift allows you to keep an eye on multiple remote machines (just like server monitoring) only with a more lightweight, heavily wireless focused, and user-friendly footprint. More info: [https://pansift.com](https://pansift.com) 
 
## Attended Installs (Free / Individual Users)

**While logged in as a user, download the [Pansift PKG](https://github.com/pansift/p3/raw/main/Pansift-0.6.1.pkg) and run it.**

You can then claim your agent from the options in the menubar or manually in the web application (using the bucket UUID code). Claiming will require you to register an account at [https://pansift.com](https://app.pansift.com/demo/logout_demo) to view your data and insights. Happy troubleshooting!

## Unattended Installs (Commercial Company / Managed Service Provider)

Unattended installs assume that an orchestration or MDM (Mobile Device Management) like platform is available to you. It also assumes command line and/or custom scripting access within a user's valid session and context (i.e. the targeted user). This approach also assumes you have paid for > 2 agents and want minimal interaction with the user(s) or endpoint(s) for provisioning.


### Step 1. Targeting New Buckets

For paid accounts (i.e. > 2 agents) please [contact support](https://pansift.com/contact) to have a commercial _multi-agent_ bucket _pre-prepared_ for you in advance (otherwise each agent will get its own bucket on the free platform and lots of individual bucket UUIDs will need to be communicated and claimed individually). We are working to simplify and automate this process.

Note: This step will be automated in future.

### Step 2. Automatic Agent Configuration Staging for Multi-Agent Installs

This method is required to **prevent** the ZTP (Zero Touch Provisioning) process from running by **pre-staging** the agent configuration required. It means you **must** specify the settings in advance of running the PKG installer. This ensures that agents will report to a specific and already claimed data bucket.

Automatic provisioning requires amending portions of the [unattended_preinstall.sh](Scripts/unattended_preinstall.sh) script and running it on remote machines **before** installing the PKG file. You must customize `3` configuration items (<BUCKET_UUID>, <INGEST_URL>, <ZTP_TOKEN>) in the [unattended_preinstall.sh](Scripts/unattended_preinstall.sh) **before** running the [Pansift PKG](https://github.com/pansift/p3/raw/main/Pansift-0.6.1.pkg) installer.

> :information_source: Buckets form one boundary for account based reads and agent writes. Buckets also define the test host records used by DNS, HTTP, and traces for all the agents in the bucket. Please consider what agents you want to report in to what buckets. Multiagent buckets allow you to administer a group of agents rather than the default 1-1 agent to bucket mapping.

> :warning: **You must run the script `unattended_preinstall.sh` script as the logged in user you wish to target and *must not* use a headless system, root/admin account, or service account.**

*Note:* You can also pre-stage fully populated `pansift_uuid.conf`, `pansift_token.conf`, and `pansift_ingest.conf` yourself if you wish (though this is what the [unattended_preinstall.sh](Scripts/unattended_preinstall.sh) does). You should be able to copy the script to your MDM or orchestration tool's pre-installation script window and ensure it is run with a logged in user.

Once the Pansift.app then runs for the first time, it bootstraps its configuration, so if the files above are **not** present, it will run the normal ZTP process to get **new random** bucket details (which you probably **don't want** as then you need to interact with the user or re-push your nominated bucket details and reainstall or restart). 

> :warning: Don't forget to run an "agent sync" in the web application after deploying new agents. 

1. Please remember for commercial/mass deployments you must run the [unattended_preinstall.sh](Scripts/unattended_preinstall.sh) script as the user account you intend to implement PanSift's RUM (Real User Monitoring) on. You should also have a full window session available to the script as it opens the Pansift application.
2. Please [contact support](https://pansift.com/contact) to create a new multi-agent bucket if you require one. You _can_ use an existing bucket if you have claimed one from a free account though data will then reside on the free Influx OSS tier (rather than the commercial Influx cloud).

#### Information on Configuration Files

> :warning: **The below files are auto-generated during standalone installs so you must populate and stage them in advance if you wish to use a multi-agent bucket as per the methods outlined above.**

 * `pansift_uuid.conf` contains a single string comprised of a UUIDv4 value e.g. `84b878ec-da07-490e-8375-c36dfbb098fa`. **YOU CAN NOT ARBITRARILY CREATE IDs YOURSELF**, they must be provisioned in advance. This is actually the bucket UUID that you want the agent to writes to. This bucket UUID is **available** from your account. If you have not claimed any buckets yet or wish to use a new and dedicated bucket then please [contact support](https://pansift.com/contact)

 * `pansift_token.conf` contains a single string comprised of an 86 character hexadecimal string ending in a double equals "==" (so it's 88 characters long). **YOU CAN NOT ARBITRARILY CREATE IDs YOURSELF**, they must be provisioned in advance. This ZTP write token is available from the bucket details in your account. The write token for the bucket can be used by multiple agents hence a 'multiagent' bucket. [Contact support](https://pansift.com/contact) if you are using a "multiagent" bucket and want discrete tokens per agent rather than creating more buckets as a grouping boundary. :warning: **This token only allows writes and not reads to a specific bucket.**

 * `pansift_ingest.conf` contains a single string comprised of a fully qualified URL for the bucket's datastore and ingest host. It takes the form of the `pansift`/`bucket` UUID as the host portion in the `ingest` subdomain. A URL example would be as such; `https://84b878ec-da07-490e-8375-c36dfbb098fa.ingest.pansift.com` (but replace with your UUID) and it needs to resolve in DNS before writes will succeed. This URL tells the agent which datastore host to speak to. The DNS entry is created during the normal ZTP process or by support (so please liaise with support for mass deployments if you are unsure). Please also check the PanSift log for an new agent or [contact support](https://pansift.com/contact) if this is not resloving for you. :information_source: The FQDN(Fully Qualified Domain Name) is a CNAME that points to the datastore A record.

> :warning: **Do not configure the `pansift_ingest.conf` datastore URL with the A record. Use "https://" + the CNAME which follows the pattern of `https://<uuid>.ingest.pansift.com`** otherwise backend operational changes may cause interruptions to your agents ability to write.
