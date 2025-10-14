# Cloudflare Infrastructure

Terraform configuration for securely exposing home server services to the internet via Cloudflare Tunnels.

## Overview

- **Cloudflare Tunnel**: Secure outbound-only connection from home server to Cloudflare edge
- **Zero Trust Access**: Authentication layer protecting exposed services  
- **DNS Management**: Automated subdomain configuration
- **No Port Forwarding**: Services accessible globally without opening router ports

## Services Exposed

- **N8N**: `https://n8n.example.com` - Automation platform

## Architecture

```
Internet → Cloudflare Edge → Encrypted Tunnel → Home Server → Services
```

Your home server creates an outbound tunnel to Cloudflare. No inbound firewall rules needed.

## Prerequisites

1. Cloudflare account with your domain
2. Cloudflare API token (see setup below)
3. Terraform >= 1.6 installed
4. Access to Cloudflare Zero Trust dashboard for identity provider setup

## API Token Setup

Create a Cloudflare API token at [dash.cloudflare.com/profile/api-tokens](https://dash.cloudflare.com/profile/api-tokens):

1. Click **Create Token**
2. Use **Custom token** template (not pre-built templates)
3. Configure permissions:
   - `Zone:Zone Settings:Edit`
   - `Zone:Zone:Read` 
   - `Zone:DNS:Edit`
   - `Account:Cloudflare Tunnel:Edit`
   - `Account:Access: Apps and Policies:Edit`
4. Set **Zone Resources** to include your domain
5. Set **Account Resources** to include your account
6. **Continue to summary** and **Create Token**
7. Copy the generated token immediately (you won't see it again)

## Setup

1. **Generate tunnel secret**: `openssl rand -base64 32`

2. **Configure**: `cp terraform.tfvars.example terraform.tfvars` and edit values

3. **Deploy**: 
   ```bash
   terraform init
   terraform apply
   ```

4. **Update environment**: Add `CLOUDFLARED_TOKEN` from terraform output to your `.env` file

5. **Setup authentication**: Configure identity provider in Cloudflare Zero Trust dashboard:
   - Go to [Zero Trust Dashboard](https://one.dash.cloudflare.com/) → Settings → Authentication
   - Add login method (Email OTP, Google, GitHub, etc.)
   - Or access your service URL and follow the setup prompt

## API Token Permissions

- **Zone:Zone Settings:Edit** - Security settings
- **Zone:Zone:Read** - Zone information  
- **Zone:DNS:Edit** - DNS records
- **Account:Cloudflare Tunnel:Edit** - Tunnel management
- **Account:Access: Apps and Policies:Edit** - Zero Trust policies

## Configuration

Key variables in `terraform.tfvars`:
- `cloudflare_api_token`: API token with above permissions
- `cloudflare_account_id`: Account ID from Cloudflare dashboard
- `tunnel_secret`: Base64 secret (generate with openssl)
- `owner_email`: Primary access email
- `enable_emergency_access`: Enable/disable emergency policies
- `emergency_emails`: Additional allowed emails

## Security Features

- **Zero Trust Access**: All requests require authentication
- **No Port Forwarding**: No open ports on home network
- **Encrypted Tunnels**: TLS encryption from edge to home server
- **Access Policies**: Email-based access control
- **Flexible Authentication**: Email OTP, OAuth (Google/GitHub), SAML

## Troubleshooting

- **Tunnel connection**: Check `docker logs cloudflared`
- **Access denied**: Verify email in policies, check authentication setup
- **DNS issues**: Ensure DNS records are proxied (orange cloud)
- **No Zero Trust**: May need to enable/upgrade Cloudflare plan

## Outputs

- `tunnel_token`: Token for cloudflared container (sensitive)
- `n8n_url`: Public URL for N8N service