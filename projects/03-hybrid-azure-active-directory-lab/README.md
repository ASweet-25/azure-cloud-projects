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

![Current Architecture — Hybrid Azure Active Directory Lab](images/current-architecture-hybrid-azure-ad-lab.png)

**Current setup:** PC01 is a Windows 11 Pro VM running locally on my Mac through UTM. It connects to DC01 in Azure over Tailscale. DC01 runs Windows Server 2025, Active Directory Domain Services, and DNS for `corp.lab.test`. The Azure user subnet is configured for future use; PC01 is not deployed inside it. The domain join is still in progress.

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

---

*This is an active learning project. I update the documentation as I complete and verify each stage.*
