# 1️⃣ Setup & Installation

This directory contains tools and scripts for setting up prerequisites and configuring the KEDA HTTP scaling environment.

## 🛠️ Available Scripts

### `quick-k6-setup.sh`
**K6 Load Testing Setup** - Automated installation and configuration
```bash
./quick-k6-setup.sh
```
**What it does:**
- Detects your OS (Ubuntu, macOS, RedHat) 
- Installs K6 load testing tool automatically
- Verifies KEDA deployment and connectivity
- Runs a quick connectivity test
- Sets up port forwarding if needed

### `apply-hybrid-fix.sh`
**Hybrid Scaling Configuration** - Applies the recommended production scaling strategy
```bash
./apply-hybrid-fix.sh
```
**What it does:**
- Configures gateways for scale-to-zero (cost optimization)
- Sets internal services to minimum 1 replica (reliability)
- Updates ConfigMaps for direct service communication
- Restarts deployments to apply changes

**When to use:** After deployment when you encounter internal service communication issues, or for production reliability.

## 🎯 Setup Workflow

### Step 1: Prerequisites
Ensure you have:
- Kubernetes cluster access
- `kubectl` configured
- `helm` installed (for KEDA installation)

### Step 2: K6 Setup (for load testing)
```bash
./quick-k6-setup.sh
```

### Step 3: Apply Hybrid Configuration (recommended for production)
```bash
./apply-hybrid-fix.sh
```
**Note:** Apply this after deployment if you experience internal service communication issues.

## 📋 Notes

- **K6 Setup**: Optional but recommended for load testing
- **Hybrid Fix**: Recommended for production reliability without app code changes
- **OS Support**: Scripts support Ubuntu, macOS, and RedHat-based systems
- **Automation**: All scripts handle prerequisites and validation automatically

## ➡️ Next Steps

After completing setup, proceed to:
**2-deploy/** - Deploy KEDA and cell architecture 