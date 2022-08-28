![pansift_social_v37](https://user-images.githubusercontent.com/4045949/153039199-940a88e8-1a62-4d78-9c74-48094f541336.jpg)

# Intro 

Pansift is a macOS troubleshooting and monitoring tool with a focus on the network. It is for those who support others **remotely** and enables them to rapidly find and fix issues (especially WiFi related). Whether you are a family member doing Zoom calls, a developer, a salesperson, or a gamer who can't afford to be disconnected, interrupted, or slowed down, Pansift makes the invisible visible for a quick fix.

Pansift is about helping others to avoid stress and stay productive with optimally functioning tools and networks. It's about saving you time, maintaining situational awareness, and getting to root causes quickly, easily, and **remotely** (even for historical issues). Whether it's for WiFi, DNS, IPv4, IPv6, or simple disk utilization issues - PanSift allows you to keep an eye on multiple remote machines (just like server monitoring) only with a more lightweight, heavily wireless focused, and user-friendly footprint. More info: [https://pansift.com](https://pansift.com) 
 
## Attended Installs (Free Users)

**Download [Pansift DMG](https://github.com/pansift/p3/raw/main/Pansift.dmg), open it, and drag `Pansift.app` to the `Applications` folder and double click to run or use Command+O to open.**

You can then claim your agent from the options in the menubar or manually in the web application (using the bucket UUID code). Claiming will require you to register an account at [https://pansift.com](https://app.pansift.com/demo/logout_demo) to view your data and insights. Happy troubleshooting!

## Unattended Installs (Company /  MSPs)

Unattended installs assume that an orchestration or MDM (Mobile Device Management) like platform is available to you including command line access within a user's valid and full window session (i.e. not just terminal access only). This also assumes you have paid for > 2 agents and want minimal interaction with the user or endpoint for provisioning.

### IT Teams and MSPs (Managed Service Providers)

For paid accounts (i.e. > 2 agents) please [contact support](https://pansift.com/contact) to have a commercial _multi-agent_ bucket _pre-prepared_ for you in advance (otherwise each agent will get its own bucket on the free platform and lots of individual bucket UUIDs will need to be communicated and claimed individually). We are working to simplify and automate this process.

### Automatic Claims For Multi-Agent Scenarios

This method **prevents** the ZTP (Zero Touch Provisioning) process from running and allows you to specify settings in advance. This ensures that agents will report to an already created and claimed data bucket.

Automatic provisioning requires staging the `Pansift.app` file from the [Pansift.app](Pansift.dmg) and then running the [unattended_preinstall.sh](Scripts/unattended_preinstall.sh) on remote machines. You also need to update `3` configuration items (<BUCKET_UUID>, <INGEST_URL>, <WRITE_TOKEN>) in the [unattended_preinstall.sh](Scripts/unattended_preinstall.sh) **before** running it.

> :information_source: Buckets form one boundary for account based reads and agent writes. Buckets also define the test host records used by DNS, HTTP, and traces for all the agents in the bucket. Please consider what agents you want to report in to what buckets. Multiagent buckets allow you to administer a group of agents rather than the default 1-1 agent to bucket mapping.

> :warning: **You must run the script as the logged in user you with to monitor and not with a headless system or service account.**

*Note:* You can also pre-stage fully populated `pansift_uuid.conf`, `pansift_token.conf`, and `pansift_ingest.conf` yourself if you wish (though this is what the [unattended_preinstall.sh](Scripts/unattended_preinstall.sh) does). You should be able to copy the script to your MDM or orchestration tool's pre-installation script window.

Once the Pansift.app then runs for the first time, it bootstraps its configuration, so if the files above are **not** present, it will run the normal ZTP process to get **new** bucket details (which you probably **don't want** as then you need to interact with the user and need to collect lots of bucket details and then claim them manually). 

You then run the [unattended_postinstall.sh](Scripts/unattended_postinstall.sh) to **remove** the user interaction requirement and then **open** the application for the first time (which will bootstrap the remaining settings). Once PanSift recognizes it has a full configuration it will use the configured *claimed* bucket without any additional provisioning process (other than an" "agent sync" being required in your account dashboard). 

This is useful for mass-deployments to machines you have access to remotely via MDM (Mobile Device Management) or other orchestration software. 

1. Please remember that you must run the script as the user account you intend to implement PanSift's RUM (Real User Monitoring) on. You must also have a full window session as you need to open the application.
2. Please [contact support](https://pansift.com/contact) to create a new multi-agent bucket. You _can_ use an existing bucket if you have claimed one already though it will probably be from the free tier.
3. For **commercial customers** please [contact support](https://pansift.com/contact) if you want to ensure your bucket and data resides in the Influx cloud rather than on one of our Influx OSS instances.

#### Information on Configuration Files

> :warning: **The below files are auto-generated by normal installs so you must populate and place them in advance if you wish to use a multi-agent bucket as per the methods outlined above.**

 * `pansift_uuid.conf` contains a single string comprised of a UUIDv4 value e.g. `84b878ec-da07-490e-8375-c36dfbb098fa`. YOU CAN NOT ARBITRARILY CREATE IDs YOURSELF, they must be provisioned in advance. This is actually the bucket UUID that you want the agent to writes to. This bucket UUID is **available** from your account. If you have not claimed any buckets yet or wish to use a new and dedicated bucket then please [contact support](https://pansift.com/contact)

 * `pansift_token.conf` contains a single string comprised of an 86 character hexadecimal string ending in a double equals "==" (so it's 88 characters long). This ZTP write token is available from the bucket details in your account. The write token for the bucket can be used by multiple agents hence a 'multiagent' bucket. [Contact support](https://pansift.com/contact) if you are using a "multiagent" bucket and want discrete tokens per agent rather than creating more buckets as a grouping boundary. :warning: **This token only allows writes and not reads to a specific bucket.**

 * `pansift_ingest.conf` contains a single string comprised of a fully qualified URL for the bucket's datastore and ingest host. It takes the form of the `pansift`/`bucket` UUID as the host portion in the `ingest` subdomain. A URL example would be as such; `https://84b878ec-da07-490e-8375-c36dfbb098fa.ingest.pansift.com` (but replace with your UUID) and it needs to resolve in DNS before writes will succeed. This URL tells the agent which datastore host to speak to. The DNS entry is created during the normal ZTP process or by support (so please liaise with support for mass deployments if you are unsure). Please also check the PanSift log for an new agent or [contact support](https://pansift.com/contact) if this is not resloving for you. :information_source: The FQDN(Fully Qualified Domain Name) is a CNAME that points to the datastore A record.

> :warning: **Do not configure the `pansift_ingest.conf` datastore URL with the A record. Use "https://" + the CNAME which follows the pattern of `https://<uuid>.ingest.pansift.com`** otherwise backend operational changes may cause interruptions to your agents ability to write.

