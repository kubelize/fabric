.PHONY: help check build test apply-claims clean validate-nix validate-claims

# Default target
help: ## Show this help message
	@echo "Fabric - GitOps Infrastructure Makefile"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

check: validate-nix validate-package ## Run all validation checks
	@echo "✓ All checks passed"

validate-nix: ## Validate Nix flake configuration
	@echo "Validating Nix flake..."
	@cd nix && nix flake check

validate-claims: ## Validate Machine claim YAML files
	@echo "Validating Machine claims..."
	@for file in crossplane/claims/*.yaml; do \
		if [ -f "$$file" ]; then \
			echo "Checking $$file..."; \
			kubectl apply --dry-run=client -f "$$file" || exit 1; \
		fi \
	done
	@echo "✓ All claims are valid"

validate-package: ## Validate Crossplane package resources
	@echo "Validating Crossplane package..."
	@echo "Checking XRD..."
	@kubectl apply --dry-run=server -f crossplane/package/xrd.yaml || exit 1
	@echo "Checking Composition..."
	@kubectl apply --dry-run=server -f crossplane/package/composition.yaml || exit 1
	@echo "✓ Package is valid"

build: ## Build all NixOS configurations
	@echo "Building all NixOS configurations..."
	@cd nix && \
	for host in $$(ls -d hosts/*/); do \
		host_name=$$(basename $$host); \
		if [ "$$host_name" != "examples" ]; then \
			echo "Building $$host_name..."; \
			nix build .#nixosConfigurations.$$host_name.config.system.build.toplevel --no-link || exit 1; \
		fi \
	done
	@echo "✓ All builds successful"

build-host: ## Build specific host (usage: make build-host HOST=dns01)
	@if [ -z "$(HOST)" ]; then \
		echo "Error: HOST variable not set. Usage: make build-host HOST=dns01"; \
		exit 1; \
	fi
	@echo "Building $(HOST)..."
	@cd nix && nix build .#nixosConfigurations.$(HOST).config.system.build.toplevel

update-flake: ## Update Nix flake dependencies
	@echo "Updating flake.lock..."
	@cd nix && nix flake update
	@echo "✓ Flake updated"

test-vm: ## Build and run a VM locally (usage: make test-vm HOST=test-vm)
	@if [ -z "$(HOST)" ]; then \
		echo "Error: HOST variable not set. Usage: make test-vm HOST=test-vm"; \
		exit 1; \
	fi
	@echo "Building VM for $(HOST)..."
	@cd nix && nixos-rebuild build-vm --flake .#$(HOST)
	@echo "Starting VM..."
	@cd nix && ./result/bin/run-$(HOST)-vm

apply-claims: ## Apply all Machine claims (requires kubectl)
	@echo "Applying Machine claims..."
	@for file in crossplane/claims/*.yaml; do \
		if [ -f "$$file" ] && [ "$$(basename $$file)" != "examples" ]; then \
			echo "Applying $$file..."; \
			kubectl apply -f "$$file"; \
		fi \
	done
	@echo "✓ Claims applied"

delete-claims: ## Delete all Machine claims
	@echo "⚠️  Deleting all Machine claims (VMs will be destroyed)..."
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		for file in crossplane/claims/*.yaml; do \
			if [ -f "$$file" ] && [ "$$(basename $$file)" != "examples" ]; then \
				echo "Deleting $$file..."; \
				kubectl delete -f "$$file" --ignore-not-found; \
			fi \
		done; \
		echo "✓ Claims deleted"; \
	else \
		echo "Cancelled"; \
	fi

status: ## Show status of all machines
	@echo "Machine Status:"
	@kubectl get machines -n infra-machines -o wide 2>/dev/null || echo "No machines found (or cluster not accessible)"

logs-crossplane: ## Show Crossplane logs
	@kubectl logs -n crossplane-system -l app=crossplane --tail=100 -f

watch-machines: ## Watch Machine resources
	@kubectl get machines -n infra-machines -w

install-package: ## Install Crossplane package (XRD + Composition)
	@echo "Installing Machine API package..."
	@kubectl apply -f crossplane/package/xrd.yaml
	@kubectl apply -f crossplane/package/composition.yaml
	@echo "✓ Package installed"
	@echo ""
	@echo "Verify installation:"
	@echo "  kubectl get xrd xmachines.infra.kubelize.io"
	@echo "  kubectl get composition"

uninstall-package: ## Uninstall Crossplane package
	@echo "⚠️  Uninstalling Machine API package..."
	@echo "⚠️  This will not delete existing Machine claims or VMs"
	@read -p "Continue? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		kubectl delete -f crossplane/package/composition.yaml --ignore-not-found; \
		kubectl delete -f crossplane/package/xrd.yaml --ignore-not-found; \
		echo "✓ Package uninstalled"; \
	else \
		echo "Cancelled"; \
	fi

setup-provider: ## Setup Crossplane provider and configuration
	@echo "Setting up Crossplane provider (provider-terraform)..."
	@echo "1. Install provider-terraform v0.15.0..."
	@kubectl apply -f - <<EOF
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-terraform
spec:
  package: xpkg.upbound.io/upbound/provider-terraform:v0.15.0
  runtimeConfigRef:
    name: provider-terraform
---
apiVersion: pkg.crossplane.io/v1beta1
kind: DeploymentRuntimeConfig
metadata:
  name: provider-terraform
spec:
  deploymentTemplate:
    spec:
      selector: {}
      template:
        spec:
          securityContext:
            fsGroup: 2000
            runAsUser: 2000
            runAsGroup: 2000
          containers:
            - name: package-runtime
              securityContext:
                runAsUser: 2000
                runAsGroup: 2000
                allowPrivilegeEscalation: false
                capabilities:
                  drop:
                    - ALL
EOF
	@echo "2. Create namespace..."
	@kubectl apply -f crossplane/config/namespace.yaml
	@echo "3. Apply ProviderConfig..."
	@kubectl apply -f crossplane/config/providerconfig-terraform.yaml
	@echo ""
	@echo "Next steps:"
	@echo "  1. Update Proxmox credentials in composition (see TODO.md)"
	@echo "  2. Install package: make install-package"

new-host: ## Create a new host from template (usage: make new-host HOST=newvm IP=10.0.1.50)
	@if [ -z "$(HOST)" ]; then \
		echo "Error: HOST variable not set. Usage: make new-host HOST=newvm IP=10.0.1.50"; \
		exit 1; \
	fi
	@echo "Creating new host $(HOST)..."
	@mkdir -p nix/hosts/$(HOST)
	@cp nix/hosts/examples/basic/configuration.nix nix/hosts/$(HOST)/
	@sed -i.bak "s/my-host/$(HOST)/g" nix/hosts/$(HOST)/configuration.nix
	@if [ ! -z "$(IP)" ]; then \
		sed -i.bak "s/10.0.1.X/$(IP)/g" nix/hosts/$(HOST)/configuration.nix; \
	fi
	@rm nix/hosts/$(HOST)/configuration.nix.bak 2>/dev/null || true
	@cp crossplane/claims/examples/basic.yaml crossplane/claims/$(HOST).yaml
	@sed -i.bak "s/test-vm/$(HOST)/g" crossplane/claims/$(HOST).yaml
	@if [ ! -z "$(IP)" ]; then \
		sed -i.bak "s/dhcp: true/ip: $(IP)\n    cidr: 24\n    gateway: 10.0.1.1\n    dns:\n      - 10.0.1.10\n      - 1.1.1.1/g" crossplane/claims/$(HOST).yaml; \
	fi
	@rm crossplane/claims/$(HOST).yaml.bak 2>/dev/null || true
	@echo "✓ Created:"
	@echo "  - nix/hosts/$(HOST)/configuration.nix"
	@echo "  - crossplane/claims/$(HOST).yaml"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Edit nix/hosts/$(HOST)/configuration.nix"
	@echo "  2. Add entry to nix/flake.nix"
	@echo "  3. Run: make build-host HOST=$(HOST)"
	@echo "  4. Commit and push"

clean: ## Clean build artifacts
	@echo "Cleaning build artifacts..."
	@cd nix && rm -f result* || true
	@echo "✓ Clean complete"

fmt-nix: ## Format Nix files
	@echo "Formatting Nix files..."
	@cd nix && find . -name "*.nix" -type f -exec nixpkgs-fmt {} +
	@echo "✓ Formatting complete"

list-hosts: ## List all configured hosts
	@echo "Configured hosts:"
	@cd nix/hosts && for dir in */; do \
		if [ "$$dir" != "examples/" ]; then \
			echo "  - $$(basename $$dir)"; \
		fi \
	done

install: ## Install everything (function + provider + package)
	@echo "Installing Crossplane function..."
	@kubectl apply -f - <<EOF
apiVersion: pkg.crossplane.io/v1beta1
kind: Function
metadata:
  name: function-patch-and-transform
spec:
  package: xpkg.upbound.io/crossplane-contrib/function-patch-and-transform:v0.10.0
EOF
	@echo "Installing provider-terraform..."
	@kubectl apply -f - <<EOF
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-terraform
spec:
  package: xpkg.upbound.io/upbound/provider-terraform:v0.15.0
  runtimeConfigRef:
    name: provider-terraform
---
apiVersion: pkg.crossplane.io/v1beta1
kind: DeploymentRuntimeConfig
metadata:
  name: provider-terraform
spec:
  deploymentTemplate:
    spec:
      selector: {}
      template:
        spec:
          securityContext:
            fsGroup: 2000
            runAsUser: 2000
            runAsGroup: 2000
          containers:
            - name: package-runtime
              securityContext:
                runAsUser: 2000
                runAsGroup: 2000
                allowPrivilegeEscalation: false
                capabilities:
                  drop:
                    - ALL
EOF
	@echo "Waiting for function..."
	@kubectl wait --for=condition=healthy function/function-patch-and-transform --timeout=180s || true
	@echo "Waiting for provider..."
	@kubectl wait --for=condition=healthy provider/provider-terraform --timeout=180s || true
	@echo "Applying ProviderConfig..."
	@kubectl apply -f crossplane/config/providerconfig-terraform.yaml
	@echo "Installing Machine API..."
	@kubectl apply -f crossplane/package/xrd.yaml
	@kubectl apply -f crossplane/package/composition.yaml
	@echo "✓ Done"
