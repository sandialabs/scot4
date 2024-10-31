## SCOT 4 Meta Repository 

For documentation about SCOT 4 please see: https://sandialabs.github.io/scot4-docs/index.html

## What is SCOT?

SCOT (Sandia Cyber Omni Tracker) is a cyber security incident response and threat intelligence management system.  Designed to keep your incident response and threat intelligence teams in sync and operating at peak efficiency.

## What does it do?

* Centralize collection of Alerts for triage by team.
* Alerts are promoted by analysts and the team's response is documented as an Event.
* IOC's are automatically identified, tracked, enriched, and linked with all appearances within the SCOT datasets.
* Events can be aggregated into Incidents to track larger problems.
* Centralize collection of Cyber intel feeds for triage by team.
* Promotion of dispatches into Intel items that are applicable to your enterprise
* Retain the results of your research into that intel and immediately see linkages to alerts and other incident data. 
* Help produce and disseminate intel Products.
* Keep track of detection Signatures and their effectiveness as well as providing a place for the team to document their usage, assumptions, and limitations.
* Centralize documentation on how to process alerts in Guides that help with team knowledge transfer.
* Provide automated actions that help remove tedious activity and speed team response times.
* Acts as a sharable, external memory for your distributed cyber security team.

## Flexible and Rewarding

SCOT has been designed to be extremely flexible and adaptable to a variety of use cases.  SCOT does not get in your way or frustrate you with burdensome rules and endless fields to fill out.  Put your work product into SCOT and it will reward you and your team by preventing rework, organically keeping the team in sync, making it easy to communicate with your team and management in a concise format, providing the data necessary to easily create more detailed reports and analysis, allowing you to easily discover linkages between various events, and automating tedious steps.

## Video demonstrations

coming soon!



## Quick Start

This repository contains a helper install script that will install k3s, helm, and the SCOT4 containers necessary to run and test a SCOT4 instance.

```
useradd -m -s /bin/bash -c "SCOT4 User" scot4
su - scot4
git clone https://github.com/sandialabs/scot4.git
cd scot4
./install.sh 
```

## Join the SCOT Community

* Support: 
    - [Issue Tracker](https://github.com/sandialabs/scot4/issues)
    - [scot4developers@sandia.gov](mailto:scot4developers@sandia.gov)
* Discussions:
    - [https://github.com/sandialabs/scot4/discussions](https://github.com/sandialabs/scot4/discussions)
* Mailing List:
    - [scot4all@sandia.gov](mailto:scot4all@sandia.gov)


