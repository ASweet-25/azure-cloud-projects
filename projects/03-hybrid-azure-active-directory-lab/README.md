# Project 03 — Hybrid Azure Active Directory Lab

**Status:** In progress | **Started:** November 2026  
**Focus:** Azure infrastructure, Windows Server administration, network security, and hybrid connectivity

## Project overview

I'm a Windows systems administrator working to strengthen my Azure administration skills while continuing to improve my traditional on-premises skills.

For this project, I'm building a small hybrid business network: a Windows Server domain controller hosted in Microsoft Azure, plus a Windows workstation VM running locally on my Mac. My goal is to learn how to deploy, secure, troubleshoot, and manage a Windows environment that spans the cloud and a remote user device.

I'm deliberately doing the work step by step rather than deploying a finished template. That gives me practice troubleshooting the same kinds of networking and authentication issues I could encounter as an administrator.

## Business problem I'm practicing

A company needs to centrally manage user identities and Windows computers even when employees work remotely.

I am recreating a simplified version of that environment with:

- **DC01 in Azure:** Windows Server 2025, Active Directory Domain Services and DNS
- **PC01 on my Mac:** Windows 11 Pro VM in UTM, representing a remote employee workstation
- **Tailscale:** Encrypted connectivity between the workstation and Azure
- **Azure VNet and NSGs:** Private addressing and network security controls
- **Azure PowerShell and Portal:** Infrastructure deployment, administration, and verification

## Architecture

```text
Remote / home environment                     Microsoft Azure — East US
+--------------------------------+            +------------------------------------------+
| MacBook Air (macOS)             |            | Resource group: rg-windows-lab           |
|                                |            | VNet-WindowsLab: 10.10.0.0/16            |
| UTM                             |            |                                          |
|   PC01 — Windows 11 Pro          |--Tailscale-->| DC01 — Windows Server 2025               |
|   User workstation (VM)          |            | SNet-Servers: 10.10.1.0/24              |
|   Tailscale connected            |            | Private IP: 10.10.1.10                  |
+--------------------------------+            | AD domain: corp.lab.test                 |
                                              | AD DS + DNS                              |
                                              | NSG-WindowsLab on DC01 NIC               |
                                              | Standard Public IP for outbound access   |
                                              |                                          |
                                              | SNet-Users: 10.10.3.0/24                 |
                                              | NSG-Users attached to user subnet        |
                                              | (no Azure user VM deployed there)        |
                                              +------------------------------------------+
```

**Important:** PC01 is hosted on my Mac, not inside the Azure user subnet. Its Active Directory join is not complete yet. Tailscale peer connectivity works; private-IP routing and AD DNS testing are the current work.

## What I've completed

1. Deployed a Windows Server 2025 Azure VM named **DC01** and configured its private address as **10.10.1.10**.
2. Built **VNet-WindowsLab** with separate server and user subnets.
3. Configured **NSG-WindowsLab** for DC01 and **NSG-Users** at the user subnet level.
4. Added an inbound rule to deny unsolicited internet connections while allowing required outbound connectivity.
5. Troubleshot failed downloads: DNS resolved correctly, but HTTPS on TCP 443 failed. I traced this to a private subnet without an outbound internet path and configured a Standard Public IP on DC01's NIC.
6. Installed and connected **Tailscale** for remote administration; configured unattended operation to support server restarts.
7. Installed and promoted DC01 to an Active Directory domain controller for **corp.lab.test**, with DNS.
8. Set the Azure VNet's custom DNS server to **10.10.1.10**.
9. Created a local Windows 11 Pro ARM VM in **UTM**, fixed its virtual network adapter issue, and verified outbound HTTPS.
10. Installed Tailscale on the local workstation VM and verified peer connectivity to DC01.

## Problems I worked through

| Problem | How I diagnosed it | What I learned |
|---|---|---|
| Tailscale download failed | Tested DNS and TCP 443 separately; checked subnet outbound access | DNS resolution does not guarantee connectivity; NSG allow rules don't create an outbound path |
| Windows VM had no network connection | Checked UTM adapter type and guest drivers; installed Windows/SPICE guest tools | A virtual NIC requires a compatible guest driver |
| Azure PowerShell command failed with a null NSG variable | Retrieved the resource with `Get-AzNetworkSecurityGroup` before updating it | Verify resource objects and command inputs before changing Azure |
| NIC interface indexes changed | Queried `Get-NetIPInterface` and used interface aliases | Don't hard-code changing interface indexes |
| Needed remote access without internet-facing RDP | Used Tailscale while blocking unsolicited inbound internet access | Secure access and outbound connectivity are separate parts of the design |

## What I'm working on next

- [ ] Verify Tailscale's advertised route from PC01 to DC01's Azure private IP
- [ ] Confirm AD DNS queries and required domain-controller ports work across the VPN
- [ ] Join PC01 to `corp.lab.test`
- [ ] Create test organizational units, users, and groups
- [ ] Apply and verify a Group Policy on PC01
- [ ] Test remote administration, server restart recovery, and cost controls
- [ ] Capture screenshots and add a final architecture diagram after validating the end-to-end setup

## Skills demonstrated so far

**Azure:** Virtual Machines, virtual networks, subnets, NSGs, public IPs, Azure Portal, Azure PowerShell, and cost awareness.

**Windows / hybrid:** Windows Server 2025, Active Directory Domain Services, DNS, PowerShell, Windows 11 ARM virtualization, Tailscale networking, and troubleshooting.

## How I would explain this project in an interview

> I'm a Windows systems administrator building my cloud skills through hands-on Azure projects. For this lab, I deployed Windows Server 2025 as a domain controller in Azure and built the supporting virtual network, subnet segmentation, and security rules. I ran into an outbound connectivity issue that prevented a software download, so I separated DNS troubleshooting from TCP connectivity testing, checked Azure's network configuration, and restored outbound access without opening internet-facing RDP.
>
> I then set up Tailscale for private remote access, promoted the server into an Active Directory domain, and built a Windows workstation VM locally on my Mac. I'm now working on joining that remote workstation to the Azure-hosted domain and applying Group Policy. The purpose is to strengthen my ability to administer both traditional Windows infrastructure and cloud-hosted resources.

## Cost and security notes

I deallocate Azure VMs outside lab sessions to control compute charges. Disks, allocated public IPs, and any deployed Bastion service may still incur charges. I avoid opening public RDP and do not store passwords, authentication keys, or subscription secrets in this repository.

---

*This is an active learning project. I update the documentation as I complete and verify each stage.*
